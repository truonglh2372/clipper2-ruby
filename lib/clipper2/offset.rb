require_relative "engine"

module Clipper2
  class ClipperOffset
    attr_accessor :miter_limit, :arc_tolerance, :reverse_solution

    def initialize(miter_limit = 2.0, arc_tolerance = 0.25)
      @miter_limit = miter_limit
      @arc_tolerance = arc_tolerance
      @groups = []
      @reverse_solution = false
    end

    def clear
      @groups.clear
      self
    end

    def add_path(path, join_type = SQUARE, end_type = POLYGON)
      @groups << [Clipper2.path64(path), join_type, end_type]
      self
    end

    def add_paths(paths, join_type = SQUARE, end_type = POLYGON)
      paths.each { |path| add_path(path, join_type, end_type) }
      self
    end

    def execute(delta, solution = nil)
      result = @groups.flat_map do |path, join_type, end_type|
        if [POLYGON, JOINED].include?(end_type)
          offset_closed(path, delta, join_type)
        else
          offset_open(path, delta, join_type, end_type)
        end
      end
      result = result.map(&:reverse) if @reverse_solution
      result = Clipper2.union(result) if result.length > 1 && delta >= 0
      solution.replace(result) if solution.respond_to?(:replace)
      result
    end

    private

    def offset_closed(path, delta, join_type)
      path = Clipper2.trim_collinear(path)
      return [] if path.length < 3 || delta == 0
      dir = Clipper2.orientation(path) ? 1.0 : -1.0
      normals = edge_normals(path, dir)
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
        convex = Clipper2.cross(path[prev_index], point, path[(index + 1) % path.length]) * dir * delta >= 0
        append_closed_join(out, point, prev, cur, delta, join_type, intersection, convex)
      end
      [Clipper2.clean_path(out)]
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

    def edge_normals(path, dir)
      path.each_with_index.map do |point, index|
        nxt = path[(index + 1) % path.length]
        normal(point, nxt, dir)
      end
    end

    def open_normals(path)
      path.each_cons(2).map { |a, b| normal(a, b, 1.0) }
    end

    def normal(a, b, dir)
      dx = b.x - a.x
      dy = b.y - a.y
      len = Math.hypot(dx, dy)
      return [0.0, 0.0] if len <= EPSILON
      [dy / len * dir, -dx / len * dir]
    end

    def offset_point(point, normal, delta)
      Point64.new(x: (point.x + normal[0] * delta).round, y: (point.y + normal[1] * delta).round, z: point.z)
    end

    def append_join(out, point, n1, n2, delta, join_type)
      # Detect whether the two offset segments meeting at this vertex separate
      # (arc/miter fill needed) or intersect (a single bisector point should
      # replace the corner). For CCW input the normal cross n1×n2 is positive
      # at convex vertices; outward (delta > 0) creates a gap there, while
      # inward (delta < 0) makes them overlap. The reverse holds at reflex
      # vertices.
      cross = n1[0] * n2[1] - n1[1] * n2[0]
      separating = (delta >= 0 ? cross : -cross) > EPSILON
      unless separating
        # Inward at convex / outward at reflex → segments overlap. Emit the
        # miter intersection so we keep a clean single corner point instead of
        # a 270° arc that swings the wrong way.
        out << miter_point(point, n1, n2, delta)
        return
      end

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
      return nil if den.abs <= EPSILON
      px = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)).to_f / den
      py = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)).to_f / den
      Point64.new(x: px.round, y: py.round)
    end

    def append_round(out, point, n1, n2, delta)
      # Caller (append_join) already filtered out the overlapping case, so
      # here we always sweep along the *shorter* arc from n1 to n2 — its sign
      # follows the cross product of the normals.
      a1 = Math.atan2(n1[1], n1[0])
      a2 = Math.atan2(n2[1], n2[0])
      sweep = a2 - a1
      sweep -= Math::PI * 2 while sweep > Math::PI
      sweep += Math::PI * 2 while sweep <= -Math::PI
      steps = [Math.sqrt(sweep.abs * delta.abs / [@arc_tolerance, 0.01].max).ceil, 1].max
      (0..steps).each do |i|
        angle = a1 + sweep * i / steps
        out << Point64.new(x: (point.x + Math.cos(angle) * delta).round, y: (point.y + Math.sin(angle) * delta).round, z: point.z)
      end
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
