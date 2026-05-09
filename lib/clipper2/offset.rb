require_relative "engine"

module Clipper2
  class ClipperOffset
    attr_accessor :miter_limit, :arc_tolerance, :preserve_collinear, :reverse_solution
    attr_reader :error_code

    def initialize(miter_limit = 2.0, arc_tolerance = 0.0, preserve_collinear = false, reverse_solution = false)
      @error_code = 0
      @miter_limit = miter_limit
      @arc_tolerance = arc_tolerance
      @preserve_collinear = preserve_collinear
      @reverse_solution = reverse_solution
      @groups = []
    end

    def clear
      @groups.clear
      self
    end

    def add_path(path, join_type = SQUARE, end_type = POLYGON)
      add_paths([path], join_type, end_type)
    end

    def add_paths(paths, join_type = SQUARE, end_type = POLYGON)
      normalized = paths.map { |p| Clipper2.path64(p) }
      is_reversed = false
      if end_type == POLYGON && !normalized.empty?
        _idx, is_neg_area = ClipperOffset.lowest_closed_path_info(normalized)
        is_reversed = !_idx.nil? && is_neg_area
      end
      @groups << { paths: normalized, join_type: join_type, end_type: end_type, is_reversed: is_reversed }
      self
    end

    def execute(delta, solution = nil)
      if @groups.empty?
        solution.replace([]) if solution.respond_to?(:replace)
        return []
      end

      if delta.abs < 0.5
        result = @groups.flat_map { |g| g[:paths].map(&:dup) }
        solution.replace(result) if solution.respond_to?(:replace)
        return result
      end

      pieces = []
      @groups.each do |g|
        paths = g[:paths]
        jt = g[:join_type]
        et = g[:end_type]
        eff =
          if et == POLYGON
            g[:is_reversed] ? -delta : delta
          else
            delta.abs
          end
        paths.each do |path|
          if et == POLYGON
            pieces.concat(offset_polygon(path, eff, jt))
          elsif et == JOINED
            pieces.concat(offset_closed(path, eff, jt))
          else
            pieces.concat(offset_open(path, eff, jt, et))
          end
        end
      end

      pieces.compact!
      pieces.reject!(&:empty?)

      total_pts = pieces.sum(&:length)
      result =
        if pieces.empty?
          []
        elsif total_pts > 500_000
          pieces
        elsif total_pts > 1200 && pieces.size == 2
          pieces.map(&:dup)
        elsif pieces.size == 1 && !@reverse_solution && total_pts <= 800
          pieces.map(&:dup)
        else
          pg = @groups.find { |g| g[:end_type] == POLYGON }
          paths_reversed = pg ? pg[:is_reversed] : false
          clip = Clipper64.new
          clip.preserve_collinear = @preserve_collinear
          clip.reverse_solution = (@reverse_solution != paths_reversed)
          clip.add_subjects(pieces)
          fr = paths_reversed ? NEGATIVE : POSITIVE
          sol = clip.execute(UNION, fr)
          sol = cleanup_offset_union(sol, fr, @preserve_collinear)
          if pieces.size == 1 && @reverse_solution && paths_reversed
            sol.each(&:reverse!)
          end
          sol
        end

      if delta < 0 && result.any?
        ib = Clipper2.bounds(@groups.flat_map { |g| g[:paths] })
        imax = [(ib.right - ib.left).abs, (ib.bottom - ib.top).abs].max
        if delta.abs > imax
          result.clear
        else
          result.reject! do |path|
            pb = Clipper2.bounds([path])
            omax = [(pb.right - pb.left).abs, (pb.bottom - pb.top).abs].max
            omax > imax + delta.abs
          end
        end
      end

      if delta < 0 && result.size > 2
        mx = result.map { |p| Clipper2.area(p).abs }.max.to_f
        fl = [mx * 1e-6, 100.0].max
        result.reject! { |p| Clipper2.area(p).abs < fl }
      end

      if delta < 0 && result.size > 1 &&
         @groups.size == 1 && @groups[0][:end_type] == POLYGON &&
         @groups[0][:paths].size == 1
        result = drop_spike_rings(result)
      end

      solution.replace(result) if solution.respond_to?(:replace)
      result
    end

    def drop_spike_rings(result)
      areas = result.map { |p| Clipper2.area(p) }
      max_idx = areas.each_with_index.max_by { |a, _| a.abs }[1]
      ref_sign = areas[max_idx] >= 0 ? 1 : -1
      kept = []
      result.each_with_index do |path, i|
        a = areas[i]
        sign = a >= 0 ? 1 : -1
        kept << path if sign == ref_sign
      end
      kept
    end

    def self.lowest_closed_path_info(paths)
      idx = nil
      bot_pt_x = 9223372036854775807
      bot_pt_y = -9223372036854775808
      is_neg_area = false
      paths.each_with_index do |path, i|
        path_area = nil
        path.each do |pt|
          next if (pt.y < bot_pt_y) || ((pt.y == bot_pt_y) && (pt.x >= bot_pt_x))

          if path_area.nil?
            path_area = Clipper2.area(path)
            break if path_area.abs <= EPSILON

            is_neg_area = path_area < 0
          end
          idx = i
          bot_pt_x = pt.x
          bot_pt_y = pt.y
        end
      end
      [idx, is_neg_area]
    end

    private

    def offset_polygon(path, eff_delta, join_type)
      path = Clipper2.trim_collinear(path, false)
      return offset_polygon_one_vertex(path, eff_delta, join_type) if path.length == 1
      return [] if path.length < 3 || eff_delta == 0
      return [] if eff_delta < 0 && eff_delta.abs < 100_000 && polygon_offset_collapses?(path, eff_delta)

      offset_closed(path, eff_delta, join_type)
    end

    def polygon_offset_collapses?(path, eff_delta)
      return false if eff_delta >= 0 || path.length < 3
      return false if eff_delta.abs < 2

      b = Clipper2.bounds([path])
      w = (b.right - b.left).abs.to_f
      h = (b.bottom - b.top).abs.to_f
      [w, h].min < 2.0 * eff_delta.abs
    end

    def cleanup_offset_union(sol, fill_rule, preserve_collinear)
      return sol if sol.nil? || sol.size <= 1
      return sol if sol.size < 10

      max_abs = sol.map { |p| Clipper2.area(p).abs }.max.to_f
      return sol if max_abs <= EPSILON

      floor = [max_abs * 5e-4, 1.0].max
      trimmed = sol.reject { |p| Clipper2.area(p).abs < floor }
      return sol if trimmed.empty?
      return trimmed if trimmed.size == 1

      c = Clipper64.new
      c.preserve_collinear = preserve_collinear
      c.reverse_solution = false
      c.add_subjects(trimmed)
      c.execute(UNION, fill_rule)
    end

    def offset_polygon_one_vertex(path, eff_delta, join_type)
      return [] if eff_delta.abs < 1

      pt = path[0]
      rad = eff_delta.abs
      if join_type == ROUND
        arc_tol = @arc_tolerance > EPSILON ? [@arc_tolerance, rad].min : [rad * 0.25, 0.01].max
        steps = [Math.sqrt(Math::PI * rad / arc_tol).ceil, 8].max
        out = []
        (0..steps).each do |i|
          ang = 2 * Math::PI * i / steps
          out << Point64.new(x: (pt.x + Math.cos(ang) * eff_delta).round, y: (pt.y + Math.sin(ang) * eff_delta).round, z: pt.z)
        end
        [Clipper2.clean_path(out)]
      else
        d = rad.ceil
        [
          [
            Point64.new(x: pt.x - d, y: pt.y - d, z: pt.z),
            Point64.new(x: pt.x + d, y: pt.y - d, z: pt.z),
            Point64.new(x: pt.x + d, y: pt.y + d, z: pt.z),
            Point64.new(x: pt.x - d, y: pt.y + d, z: pt.z)
          ]
        ]
      end
    end

    def offset_closed(path, delta, join_type)
      path = Clipper2.trim_collinear(path, false)
      return [] if path.length < 3 || delta == 0
      normals = polygon_edge_normals(path)
      offset_edges = path.each_with_index.map do |point, index|
        nxt = path[(index + 1) % path.length]
        normal = normals[index]
        [offset_point(point, normal, delta), offset_point(nxt, normal, delta)]
      end
      out = []
      path.length.times do |index|
        prev_index = (index - 1) % path.length
        point = path[index]
        prev = normals[prev_index]
        cur = normals[index]
        intersection = line_intersection(offset_edges[prev_index][0], offset_edges[prev_index][1], offset_edges[index][0], offset_edges[index][1])
        sin_a = prev[0] * cur[1] - prev[1] * cur[0]
        sin_a = 1.0 if sin_a > 1.0
        sin_a = -1.0 if sin_a < -1.0
        cos_a = prev[0] * cur[0] + prev[1] * cur[1]
        concave = cos_a > -0.999 && (sin_a * delta < 0)
        convex = !concave
        append_closed_join(out, point, prev, cur, delta, join_type, intersection, convex)
      end
      cleaned = Clipper2.clean_path(out)
      return [] if cleaned.length < 3
      [cleaned]
    end

    def append_closed_join(out, point, n1, n2, delta, join_type, intersection, convex)
      if !convex && intersection && Clipper2.distance(point, intersection) <= delta.abs * @miter_limit
        return out << intersection
      elsif !convex
        out << offset_point(point, n1, delta)
        return out << offset_point(point, n2, delta)
      end
      case join_type
      when ROUND
        append_round(out, point, n1, n2, delta)
      when MITER
        if intersection && Clipper2.distance(point, intersection) <= delta.abs * @miter_limit
          out << intersection
        else
          out << offset_point(point, n1, delta)
          out << offset_point(point, n2, delta)
        end
      else
        out << offset_point(point, n1, delta)
        out << offset_point(point, n2, delta)
      end
    end

    def offset_open(path, delta, join_type, end_type)
      return [] if path.length < 2 || delta == 0
      left = []
      right = []
      normals = open_normals(path)
      path.each_with_index do |point, index|
        if index.zero?
          n = normals[0]
          left << offset_point(point, n, delta)
          right << offset_point(point, n, -delta)
        elsif index == path.length - 1
          n = normals[-1]
          left << offset_point(point, n, delta)
          right << offset_point(point, n, -delta)
        else
          append_join(left, point, normals[index - 1], normals[index], delta, join_type)
          append_join(right, point, normals[index - 1], normals[index], -delta, join_type)
        end
      end
      outline = left + cap_points(path[-1], normals[-1], delta, end_type, false) + right.reverse + cap_points(path[0], normals[0], delta, end_type, true)
      [Clipper2.clean_path(outline)]
    end

    def polygon_edge_normals(path)
      path.each_with_index.map do |point, index|
        nxt = path[(index + 1) % path.length]
        unit_normal_xy(point, nxt)
      end
    end

    def open_normals(path)
      path.each_cons(2).map { |a, b| normal(a, b, 1.0) }
    end

    def unit_normal_xy(a, b)
      dx = b.x - a.x
      dy = b.y - a.y
      len = Math.hypot(dx, dy)
      return [0.0, 0.0] if len <= EPSILON
      inv = 1.0 / len
      [dy * inv, -dx * inv]
    end

    def normal(a, b, dir)
      u = unit_normal_xy(a, b)
      [u[0] * dir, u[1] * dir]
    end

    def offset_point(point, normal, delta)
      Point64.new(x: (point.x + normal[0] * delta).round, y: (point.y + normal[1] * delta).round, z: point.z)
    end

    def append_join(out, point, n1, n2, delta, join_type)
      case join_type
      when ROUND
        append_round(out, point, n1, n2, delta)
      when MITER
        miter = miter_point(point, n1, n2, delta)
        if Clipper2.distance(point, miter) <= delta.abs * @miter_limit
          out << miter
        else
          out << offset_point(point, n1, delta)
          out << offset_point(point, n2, delta)
        end
      else
        out << offset_point(point, n1, delta)
        out << offset_point(point, n2, delta)
      end
    end

    def miter_point(point, n1, n2, delta)
      q1 = offset_point(point, n1, delta)
      q2 = Point64.new(x: (q1.x + -n1[1] * 10_000_000).round, y: (q1.y + n1[0] * 10_000_000).round)
      r1 = offset_point(point, n2, delta)
      r2 = Point64.new(x: (r1.x + -n2[1] * 10_000_000).round, y: (r1.y + n2[0] * 10_000_000).round)
      line_intersection(q1, q2, r1, r2) || offset_point(point, n2, delta)
    end

    def line_intersection(a, b, c, d)
      x1 = a.x
      y1 = a.y
      x2 = b.x
      y2 = b.y
      x3 = c.x
      y3 = c.y
      x4 = d.x
      y4 = d.y
      den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
      return nil if den.zero?

      n12 = x1 * y2 - y1 * x2
      n34 = x3 * y4 - y3 * x4
      numx = n12 * (x3 - x4) - (x1 - x2) * n34
      numy = n12 * (y3 - y4) - (y1 - y2) * n34
      rx = numx.to_r / den
      ry = numy.to_r / den
      Point64.new(x: rx.round, y: ry.round)
    end

    def append_round(out, point, n1, n2, delta)
      abs_d = delta.abs
      return out << offset_point(point, n2, delta) if abs_d < EPSILON

      arc_tol = @arc_tolerance > EPSILON ? [abs_d, @arc_tolerance].min : abs_d * 0.002
      arc_tol = [arc_tol, 1e-15].max
      cos_inner = 1.0 - arc_tol / abs_d
      cos_inner = [[cos_inner, -1.0].max, 1.0].min
      steps_per_360 = [Math::PI / Math.acos(cos_inner), abs_d * Math::PI].min
      step_sin = Math.sin(2 * Math::PI / steps_per_360)
      step_cos = Math.cos(2 * Math::PI / steps_per_360)
      step_sin = -step_sin if delta < 0.0
      steps_per_rad = steps_per_360 / (2 * Math::PI)

      a1 = Math.atan2(n1[1], n1[0])
      a2 = Math.atan2(n2[1], n2[0])
      if delta >= 0
        a2 += Math::PI * 2 while a2 < a1
      else
        a2 -= Math::PI * 2 while a2 > a1
      end
      sweep = a2 - a1

      vec_x = n1[0] * delta
      vec_y = n1[1] * delta
      out << Point64.new(x: (point.x + vec_x).round, y: (point.y + vec_y).round, z: point.z)

      steps = [(steps_per_rad * sweep.abs).ceil.to_i, 1].max
      (1...steps).each do
        nx = vec_x * step_cos - step_sin * vec_y
        ny = vec_x * step_sin + step_cos * vec_y
        vec_x = nx
        vec_y = ny
        out << Point64.new(x: (point.x + vec_x).round, y: (point.y + vec_y).round, z: point.z)
      end
      out << offset_point(point, n2, delta)
    end

    def cap_points(point, normal, delta, end_type, start_cap)
      case end_type
      when ROUND_END
        tangent = [-normal[1], normal[0]]
        from = start_cap ? -delta : delta
        center = point
        steps = [Math.sqrt(Math::PI * delta.abs / [@arc_tolerance, 0.01].max).ceil, 4].max
        (0..steps).map do |i|
          angle = Math::PI * i / steps
          side = from * Math.cos(angle)
          forward = delta.abs * Math.sin(angle) * (start_cap ? -1 : 1)
          Point64.new(x: (center.x + normal[0] * side + tangent[0] * forward).round, y: (center.y + normal[1] * side + tangent[1] * forward).round)
        end
      when SQUARE_END
        tangent = [-normal[1], normal[0]]
        [
          Point64.new(x: (point.x + normal[0] * delta + tangent[0] * delta).round, y: (point.y + normal[1] * delta + tangent[1] * delta).round),
          Point64.new(x: (point.x - normal[0] * delta + tangent[0] * delta).round, y: (point.y - normal[1] * delta + tangent[1] * delta).round)
        ]
      else
        []
      end
    end
  end

  module_function

  def inflate_paths(paths, delta, join_type = SQUARE, end_type = POLYGON, miter_limit = 2.0, arc_tolerance = 0.25)
    offset = ClipperOffset.new(miter_limit, arc_tolerance)
    offset.add_paths(paths, join_type, end_type)
    offset.execute(delta)
  end
end
