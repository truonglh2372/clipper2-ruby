require_relative "core"

module Clipper2
  NO_CLIP = :no_clip
  PATH_TYPE_SUBJECT = :subject
  PATH_TYPE_CLIP = :clip

  JOIN_WITH_NO_JOIN = :no_join
  JOIN_WITH_LEFT = :left
  JOIN_WITH_RIGHT = :right

  VERTEX_FLAG_EMPTY = 0
  VERTEX_FLAG_OPEN_START = 1
  VERTEX_FLAG_OPEN_END = 2
  VERTEX_FLAG_LOCAL_MAX = 4
  VERTEX_FLAG_LOCAL_MIN = 8

  module VertexFlags
    EMPTY = VERTEX_FLAG_EMPTY
    OPEN_START = VERTEX_FLAG_OPEN_START
    OPEN_END = VERTEX_FLAG_OPEN_END
    LOCAL_MAX = VERTEX_FLAG_LOCAL_MAX
    LOCAL_MIN = VERTEX_FLAG_LOCAL_MIN

    module_function

    def &(a, b)
      a.to_i & b.to_i
    end

    def |(a, b)
      a.to_i | b.to_i
    end
  end

  PolyPath64 = PolyPath
  PolyTree64 = PolyTree

  class Scanline
    attr_accessor :y, :next_sl

    def initialize(y)
      @y = y
      @next_sl = nil
    end
  end

  class ClipperVertex
    attr_accessor :pt, :next_vertex, :prev_vertex, :flags

    def initialize(pt = nil)
      @pt = pt
      @next_vertex = nil
      @prev_vertex = nil
      @flags = VERTEX_FLAG_EMPTY
    end
  end

  class ClipperOutPt
    attr_accessor :pt, :next_op, :prev_op, :outrec, :horz

    def initialize(pt, outrec)
      @pt = pt
      @outrec = outrec
      @horz = nil
      @next_op = self
      @prev_op = self
    end
  end

  class ClipperOutRec
    attr_accessor :idx, :owner, :front_edge, :back_edge, :pts, :polypath, :splits,
                  :recursive_split, :bounds, :path, :is_open

    def initialize
      @idx = 0
      @owner = nil
      @front_edge = nil
      @back_edge = nil
      @pts = nil
      @polypath = nil
      @splits = nil
      @recursive_split = nil
      @bounds = Rect64.valid_empty
      @path = []
      @is_open = false
    end
  end

  class ClipperActive
    attr_accessor :bot, :top, :curr_x, :dx, :wind_dx, :wind_cnt, :wind_cnt2,
                  :outrec, :prev_in_ael, :next_in_ael, :prev_in_sel, :next_in_sel,
                  :jump, :vertex_top, :local_min, :is_left_bound, :join_with

    def initialize
      @bot = nil
      @top = nil
      @curr_x = 0
      @dx = 0.0
      @wind_dx = 1
      @wind_cnt = 0
      @wind_cnt2 = 0
      @outrec = nil
      @prev_in_ael = nil
      @next_in_ael = nil
      @prev_in_sel = nil
      @next_in_sel = nil
      @jump = nil
      @vertex_top = nil
      @local_min = nil
      @is_left_bound = false
      @join_with = JOIN_WITH_NO_JOIN
    end
  end

  class ClipperLocalMinima
    attr_accessor :vertex, :polytype, :is_open

    def initialize(vertex, polytype, is_open)
      @vertex = vertex
      @polytype = polytype
      @is_open = is_open
    end
  end

  class ClipperIntersectNode
    attr_accessor :pt, :edge1, :edge2

    def initialize(edge1 = nil, edge2 = nil, pt = nil)
      @pt = pt || Point64.new(x: 0, y: 0)
      @edge1 = edge1
      @edge2 = edge2
    end
  end

  class ClipperHorzSegment
    attr_accessor :left_op, :right_op, :left_to_right

    def initialize(left_op = nil)
      @left_op = left_op
      @right_op = nil
      @left_to_right = true
    end
  end

  class ClipperHorzJoin
    attr_accessor :op1, :op2

    def initialize(op1 = nil, op2 = nil)
      @op1 = op1
      @op2 = op2
    end
  end

  class ReuseableDataContainer64
    def initialize
      @batches = []
      @vertex_lists = []
    end

    def clear
      @batches.clear
      @vertex_lists.clear
    end

    def add_paths(paths, polytype, is_open)
      @batches << [paths, polytype, is_open]
    end

    def each_batch(&block)
      @batches.each(&block)
    end

    attr_reader :vertex_lists
  end

  class PolyPathD < PolyPath
    attr_accessor :scale_value

    def initialize(polygon: [], children: [], parent: nil, scale: nil)
      super(polygon: polygon, children: children, parent: parent)
      @scale_value =
        if scale.nil?
          parent.is_a?(PolyPathD) ? parent.scale_value : 1.0
        else
          scale
        end
    end

    def scale
      @scale_value
    end

    def add_child(path)
      child =
        case path
        when PolyPathD
          path
        when PolyPath
          PolyPathD.new(polygon: path.polygon, children: [], parent: self, scale: @scale_value)
        else
          PolyPathD.new(polygon: path, parent: self, scale: @scale_value)
        end
      child.parent = self
      child.scale_value = @scale_value if child.is_a?(PolyPathD)
      children << child
      child
    end

    def subtree_area
      Clipper2.area(polygon) + children.sum(&:subtree_area)
    end
  end

  PolyTreeD = PolyPathD

  module PolytreePaths
    module_function

    def path_geom_contains?(outer, inner)
      return false if outer.object_id == inner.object_id
      ob = Clipper2.bounds([outer])
      ib = Clipper2.bounds([inner])
      return false if ob.invalid? || ib.invalid?
      return false unless ob.contains_rect?(ib)
      inner.each do |pt|
        return false if Clipper2.point_in_polygon(pt, outer) == Clipper2::OUTSIDE
      end
      true
    end

    def populate_tree(tree, paths)
      paths = paths.map { |p| Clipper2.path64(p) }.reject { |p| p.length < 3 }
      tree.clear_children
      build_roots(paths).each do |root|
        root.parent = tree
        tree.children << root
      end
      tree
    end

    def build_roots(paths)
      n = paths.length
      return [] if n.zero?
      abs_areas = paths.map { |p| Clipper2.area(p).abs }
      parent = Array.new(n, nil)
      n.times do |j|
        candidates = []
        n.times do |i|
          next if i == j
          next unless abs_areas[i] > abs_areas[j]
          candidates << i if path_geom_contains?(paths[i], paths[j])
        end
        parent[j] = candidates.min_by { |i| [abs_areas[i], i] } unless candidates.empty?
      end
      children = Hash.new { |h, k| h[k] = [] }
      n.times { |j| children[parent[j]] << j }
      nil_keys = (children[nil] || []).sort_by { |idx| bounds_sort_key(paths[idx]) }
      nil_keys.map { |idx| build_node(idx, paths, children) }
    end

    def bounds_sort_key(path)
      b = Clipper2.bounds([path])
      [b.left, b.top, b.right, b.bottom]
    end

    def build_node(idx, paths, children)
      node = PolyPath.new(polygon: paths[idx])
      (children[idx] || []).sort_by { |cidx| bounds_sort_key(paths[cidx]) }.each do |cidx|
        ch = build_node(cidx, paths, children)
        ch.parent = node
        node.children << ch
      end
      node
    end

    def append_polytree64_branch(parent_d, node64, scale)
      pd = PolyPathD.new(polygon: Clipper2.unscale_path(node64.polygon, scale), parent: parent_d, scale: parent_d.scale_value)
      parent_d.children << pd
      node64.children.each do |ch|
        append_polytree64_branch(pd, ch, scale)
      end
      pd
    end
  end

  class ClipperBase
    attr_reader :error_code, :has_open_paths

    attr_writer :preserve_collinear, :reverse_solution

    def preserve_collinear
      @preserve_collinear
    end

    alias preserve_collinear? preserve_collinear

    def reverse_solution
      @reverse_solution
    end

    alias reverse_solution? reverse_solution

    def initialize
      @preserve_collinear = true
      @reverse_solution = false
      @error_code = 0
      @succeeded = true
      @has_open_paths = false
      @subjects = []
      @clips = []
      @open_subjects = []
      @last_closed_result = nil
      @last_open_result = nil
    end

    def succeeded?
      @succeeded
    end

    alias succeeded succeeded?

    def clear
      @subjects.clear
      @clips.clear
      @open_subjects.clear
      @has_open_paths = false
      self
    end

    def add_reuseable_data(container)
      container.each_batch do |paths, polytype, is_open|
        if polytype == PATH_TYPE_SUBJECT || polytype == :subject
          if is_open
            add_open_subjects(paths)
          else
            add_subjects(paths)
          end
        else
          add_clips(paths)
        end
      end
      self
    end

    def add_subject(path)
      add_subjects([path])
    end

    def add_subjects(paths)
      paths.each { |path| @subjects << normalize_subject_path(path) }
      self
    end

    def add_clip(path)
      add_clips([path])
    end

    def add_clips(paths)
      paths.each { |path| @clips << normalize_clip_path(path) }
      self
    end

    def add_open_subject(path)
      add_open_subjects([path])
    end

    def add_open_subjects(paths)
      @has_open_paths = true
      paths.each { |path| @open_subjects << normalize_open_path(path) }
      self
    end

    protected

    def execute_internal(clip_type, fill_rule, _use_polytrees)
      subjects = @subjects.map { |path| Clipper2.clean_path(path) }.reject { |path| path.length < 3 }
      clips = @clips.map { |path| Clipper2.clean_path(path) }.reject { |path| path.length < 3 }
      @last_closed_result = BooleanEngine.execute(subjects, clips, clip_type, fill_rule, point_class: Point64)
      open_clean = @open_subjects.map { |path| Clipper2.clean_path(path) }.reject { |path| path.length < 2 }
      @last_open_result = compute_open_paths_solution(open_clean, clips, clip_type, fill_rule, subjects)
      @succeeded = true
      true
    end

    def post_process_closed(result)
      r = (result || []).map(&:dup)
      r.map!(&:reverse) if @reverse_solution
      r.map! { |path| Clipper2.trim_collinear(path, false) }
      r.reject! { |path| path.length < 3 || Clipper2.area(path).abs <= EPSILON }
      r
    end

    def clean_up_after_execute
      @last_closed_result = nil
      @last_open_result = nil
    end

    def normalize_subject_path(path)
      normalize_closed_path(path)
    end

    def normalize_clip_path(path)
      normalize_closed_path(path)
    end

    def normalize_closed_path(path)
      raise NotImplementedError
    end

    def normalize_open_path(path)
      raise NotImplementedError
    end

    def point_class
      Point64
    end

    def build_open_solution
      (@last_open_result || []).map { |path| path.map(&:dup) }
    end

    private

    def compute_open_paths_solution(open_paths, clips, clip_type, fill_rule, closed_subjects)
      return [] if open_paths.empty?
      case clip_type
      when NO_CLIP
        open_paths.map(&:dup)
      when INTERSECTION
        return [] if closed_subjects.empty?
        open_paths.flat_map { |path| clip_open_polyline(path, clips, fill_rule, :intersection) }
      when DIFFERENCE
        open_paths.flat_map { |path| clip_open_polyline(path, clips, fill_rule, :difference) }
      when UNION, XOR
        open_paths.map(&:dup)
      else
        open_paths.map(&:dup)
      end
    end

    def clip_open_polyline(path, clips, fill_rule, mode)
      return [] if path.length < 2
      return [path.dup] if clips.empty?
      chains = []
      path.each_cons(2) do |a, b|
        next if a.x == b.x && a.y == b.y
        parts = segment_clip_parts(a, b, clips, fill_rule, mode)
        merge_open_chains!(chains, parts)
      end
      chains.map { |ch| dedupe_consecutive_points(ch) }.reject { |ch| ch.length < 2 }
    end

    def merge_open_chains!(chains, parts)
      parts.each do |pa, pb|
        if chains.empty?
          chains << [pa, pb]
        elsif points_equal64?(chains.last[-1], pa)
          chains.last << pb
        elsif points_equal64?(chains.last[-1], pb)
          chains.last << pa
        else
          chains << [pa, pb]
        end
      end
    end

    def points_equal64?(a, b)
      a.x == b.x && a.y == b.y
    end

    def dedupe_consecutive_points(path)
      path.each_with_object([]) do |p, acc|
        acc << p if acc.empty? || !points_equal64?(acc[-1], p)
      end
    end

    def segment_clip_parts(a, b, clips, fill_rule, mode)
      segment_split_params(a, b, clips).each_cons(2).each_with_object([]) do |(t0, t1), acc|
        next if (t1 - t0) <= 1e-12
        pa = lerp_seg64(a, b, t0)
        pb = lerp_seg64(a, b, t1)
        t_mid = (t0 + t1) / 2.0
        mx = a.x + (b.x - a.x) * t_mid
        my = a.y + (b.y - a.y) * t_mid
        mid = PointD.new(x: mx, y: my, z: a.z)
        r = Clipper2.point_in_paths(mid, clips, fill_rule)
        keep =
          case mode
          when :difference
            r == false
          when :intersection
            r == true || r == Clipper2::ON
          else
            false
          end
        acc << [pa, pb] if keep
      end
    end

    def segment_split_params(a, b, clips)
      ts = [0.0, 1.0]
      clips.each do |poly|
        next if poly.length < 2
        poly.length.times do |i|
          c = poly[i]
          d = poly[(i + 1) % poly.length]
          ok, ip = Clipper2.get_line_intersect_pt(a, b, c, d)
          next unless ok
          next unless Clipper2.on_segment?(a, b, ip)
          next unless Clipper2.on_segment?(c, d, ip)
          t = seg_param_t(a, b, ip)
          ts << t if t > 1e-12 && t < 1.0 - 1e-12
        end
      end
      ts.uniq { |v| (v * 1_000_000_000_000).round }.sort
    end

    def seg_param_t(a, b, p)
      dx = (b.x - a.x).to_f
      dy = (b.y - a.y).to_f
      adx = dx.abs
      ady = dy.abs
      if adx >= ady && adx >= EPSILON
        (p.x - a.x) / dx
      elsif ady >= EPSILON
        (p.y - a.y) / dy
      else
        0.0
      end
    end

    def lerp_seg64(a, b, t)
      Point64.new(
        x: (a.x + (b.x - a.x) * t).round,
        y: (a.y + (b.y - a.y) * t).round,
        z: a.z
      )
    end
  end

  class Clipper64 < ClipperBase
    def execute(clip_type, fill_rule = NON_ZERO, closed_paths = nil, open_paths = nil)
      return execute_closed_open(clip_type, fill_rule, closed_paths, open_paths) unless open_paths.nil?
      execute_internal(clip_type, fill_rule, false)
      out = post_process_closed(@last_closed_result)
      clean_up_after_execute
      if closed_paths && !closed_paths.is_a?(Array) && closed_paths.respond_to?(:replace)
        closed_paths.replace(out)
      end
      out
    end

    def execute_closed_open(clip_type, fill_rule, closed_paths, open_paths)
      execute_internal(clip_type, fill_rule, false)
      closed_paths.replace(post_process_closed(@last_closed_result)) if closed_paths.respond_to?(:replace)
      open_paths.replace(build_open_solution) if open_paths.respond_to?(:replace)
      clean_up_after_execute
      succeeded?
    end

    def execute_polytree(clip_type, fill_rule = NON_ZERO, polytree = nil, open_paths = nil)
      unless open_paths.nil?
        execute_polytree_open(clip_type, fill_rule, polytree, open_paths)
      else
        execute_internal(clip_type, fill_rule, true)
        sol = post_process_closed(@last_closed_result)
        tree = polytree.is_a?(PolyTree) ? polytree : PolyTree.new
        PolytreePaths.populate_tree(tree, sol)
        clean_up_after_execute
        tree
      end
    end

    def execute_polytree_open(clip_type, fill_rule, polytree, open_paths)
      execute_internal(clip_type, fill_rule, true)
      sol = post_process_closed(@last_closed_result)
      tree = polytree.is_a?(PolyTree) ? polytree : PolyTree.new
      PolytreePaths.populate_tree(tree, sol)
      open_paths.replace(build_open_solution) if open_paths.respond_to?(:replace)
      clean_up_after_execute
      succeeded?
    end

    private

    def normalize_closed_path(path)
      result = Clipper2.path64(path)
      Clipper2.trim_collinear(result, false)
    end

    def normalize_open_path(path)
      Clipper2.path64(path)
    end
  end

  class ClipperD < ClipperBase
    attr_reader :scale, :inv_scale, :precision

    def initialize(precision = 2)
      super()
      @error_holder = [0]
      @precision = Clipper2.check_precision_range(precision, @error_holder)
      @error_code = @error_holder[0]
      @scale = ClipperD.radix_scale(@precision)
      @inv_scale = 1.0 / @scale
    end

    def self.radix_scale(precision)
      p = Clipper2.check_precision_range(precision)
      p10 = 10.0**p
      return 1.0 if !p10.finite? || p10.zero?
      exp = (Math.log(p10.abs) / Math.log(2.0)).floor
      2.0**(exp + 1)
    end

    def execute(clip_type, fill_rule = NON_ZERO, closed_paths = nil, open_paths = nil)
      ec = [@error_code]
      subj = Clipper2.scale_paths(@subjects, @scale, @scale, ec)
      clips = Clipper2.scale_paths(@clips, @scale, @scale, ec)
      @error_code = ec[0]
      temp = Clipper64.new
      temp.preserve_collinear = @preserve_collinear
      temp.reverse_solution = @reverse_solution
      temp.add_subjects(subj)
      temp.add_clips(clips)
      @open_subjects.each { |op| temp.add_open_subjects([Clipper2.scale_path(op, @scale, @scale, ec)]) }
      @error_code = ec[0]
      unless open_paths.nil?
        ok = temp.execute_closed_open(clip_type, fill_rule, closed_paths, open_paths)
        if closed_paths.respond_to?(:replace)
          closed_paths.replace(Clipper2.unscale_paths(closed_paths, @scale))
        end
        if open_paths.respond_to?(:replace)
          open_paths.replace(Clipper2.unscale_paths(open_paths, @scale))
        end
        return ok
      end
      raw64 = temp.execute(clip_type, fill_rule)
      out = Clipper2.unscale_paths(raw64, @scale)
      if closed_paths && !closed_paths.is_a?(Array) && closed_paths.respond_to?(:replace)
        closed_paths.replace(out)
      end
      out
    end

    def execute_polytree(clip_type, fill_rule = NON_ZERO, polytree = nil, open_paths = nil)
      ec = [@error_code]
      subj = Clipper2.scale_paths(@subjects, @scale, @scale, ec)
      clips = Clipper2.scale_paths(@clips, @scale, @scale, ec)
      @error_code = ec[0]
      temp = Clipper64.new
      temp.preserve_collinear = @preserve_collinear
      temp.reverse_solution = @reverse_solution
      temp.add_subjects(subj)
      temp.add_clips(clips)
      @open_subjects.each { |op| temp.add_open_subjects([Clipper2.scale_path(op, @scale, @scale, ec)]) }
      if open_paths.nil?
        tree64 = PolyTree.new
        temp.execute_polytree(clip_type, fill_rule, tree64)
        tree = polytree.is_a?(PolyPathD) ? polytree : PolyPathD.new(scale: @inv_scale)
        tree.clear_children
        tree.scale_value = @inv_scale
        tree64.children.each { |ch| PolytreePaths.append_polytree64_branch(tree, ch, @scale) }
        tree
      else
        tree64 = polytree.is_a?(PolyTree) ? polytree : PolyTree.new
        ok = temp.execute_polytree_open(clip_type, fill_rule, tree64, open_paths)
        open_paths.replace(Clipper2.unscale_paths(open_paths, @scale)) if open_paths.respond_to?(:replace)
        ok
      end
    end

    private

    def normalize_closed_path(path)
      result = Clipper2.pathd(path)
      Clipper2.trim_collinear(result, false)
    end

    def normalize_open_path(path)
      Clipper2.pathd(path)
    end
  end

  class BooleanEngine
    class << self
      def execute(subjects, clips, clip_type, fill_rule, point_class:, union_boundary_all: false)
        return subjects.map(&:dup) if clip_type == NO_CLIP
        subjects = subjects.map { |path| Clipper2.clean_path(path) }.reject { |path| path.length < 3 }
        clips = clips.map { |path| Clipper2.clean_path(path) }.reject { |path| path.length < 3 }
        return [] if subjects.empty? || (clip_type == INTERSECTION && clips.empty?)
        fragments = split_fragments(subjects, clips)
        selected = fragments.filter_map { |fragment| select_fragment(fragment, subjects, clips, clip_type, fill_rule, union_boundary_all) }
        stitch(selected, point_class)
      end

      private

      def split_fragments(subjects, clips)
        edges = []
        subjects.each_with_index { |path, path_index| append_edges(edges, path, :subject, path_index) }
        clips.each_with_index { |path, path_index| append_edges(edges, path, :clip, path_index) }
        params = Array.new(edges.length) { [0.0, 1.0] }
        edges.each_with_index do |edge_a, i|
          edges.each_with_index do |edge_b, j|
            next if j <= i
            next if polygon_adjacent_edges?(edge_a, edge_b)
            segment_intersections(edge_a[:a], edge_a[:b], edge_b[:a], edge_b[:b]).each do |t, u|
              params[i] << t if t >= -EPSILON && t <= 1.0 + EPSILON
              params[j] << u if u >= -EPSILON && u <= 1.0 + EPSILON
            end
          end
        end
        fragments = []
        edges.each_with_index do |edge, index|
          ts = params[index].map { |value| [[value, 0.0].max, 1.0].min }.uniq { |value| (value * 1_000_000_000_000).round }.sort
          ts.each_cons(2) do |t1, t2|
            next if (t2 - t1).abs <= EPSILON
            a = interpolate(edge[:a], edge[:b], t1)
            b = interpolate(edge[:a], edge[:b], t2)
            next if same_point?(a, b)
            fragments << EdgeFragment.new(a: a, b: b, source: edge[:source])
          end
        end
        fragments
      end

      def append_edges(edges, path, source, path_index)
        path_len = path.length
        path.each_with_index do |point, index|
          edges << {
            a: point,
            b: path[(index + 1) % path_len],
            source: source,
            path_index: path_index,
            edge_index: index,
            path_len: path_len
          }
        end
      end

      def polygon_adjacent_edges?(ea, eb)
        return false unless ea[:source] == eb[:source] && ea[:path_index] == eb[:path_index]
        return true if ea[:edge_index] == eb[:edge_index]
        n = ea[:path_len]
        ia = ea[:edge_index]
        ib = eb[:edge_index]
        (ia + 1) % n == ib || (ib + 1) % n == ia
      end

      def segment_intersections(a, b, c, d)
        r_x = b.x - a.x
        r_y = b.y - a.y
        s_x = d.x - c.x
        s_y = d.y - c.y
        denom = r_x * s_y - r_y * s_x
        cma_x = c.x - a.x
        cma_y = c.y - a.y
        if denom.abs <= EPSILON
          return [] unless (cma_x * r_y - cma_y * r_x).abs <= EPSILON
          rr = r_x * r_x + r_y * r_y
          return [] if rr <= EPSILON
          t0 = (cma_x * r_x + cma_y * r_y).to_f / rr
          t1 = ((d.x - a.x) * r_x + (d.y - a.y) * r_y).to_f / rr
          min_t, max_t = [t0, t1].minmax
          lo = [min_t, 0.0].max
          hi = [max_t, 1.0].min
          return [] if hi < lo - EPSILON
          return [[lo, param_on_segment(c, d, interpolate(a, b, lo))], [hi, param_on_segment(c, d, interpolate(a, b, hi))]]
        end
        t = (cma_x * s_y - cma_y * s_x).to_f / denom
        u = (cma_x * r_y - cma_y * r_x).to_f / denom
        return [] unless t >= -EPSILON && t <= 1.0 + EPSILON && u >= -EPSILON && u <= 1.0 + EPSILON
        [[t, u]]
      end

      def param_on_segment(a, b, p)
        dx = b.x - a.x
        dy = b.y - a.y
        denom = dx.abs >= dy.abs ? dx : dy
        return 0.0 if denom.abs <= EPSILON
        dx.abs >= dy.abs ? (p.x - a.x).to_f / dx : (p.y - a.y).to_f / dy
      end

      def interpolate(a, b, t)
        if a.is_a?(Point64) && b.is_a?(Point64)
          Point64.new(x: (a.x + (b.x - a.x) * t).round, y: (a.y + (b.y - a.y) * t).round, z: a.z)
        else
          PointD.new(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, z: a.z)
        end
      end

      def midpoint(fragment)
        interpolate(fragment.a, fragment.b, 0.5)
      end

      def classification_midpoint(fragment)
        ax = fragment.a.x.to_f
        ay = fragment.a.y.to_f
        bx = fragment.b.x.to_f
        by = fragment.b.y.to_f
        PointD.new(x: (ax + bx) / 2.0, y: (ay + by) / 2.0, z: fragment.a.z)
      end

      def select_fragment(fragment, subjects, clips, clip_type, fill_rule, union_boundary_all)
        mid =
          if clip_type == INTERSECTION
            classification_midpoint(fragment)
          else
            midpoint(fragment)
          end
        subject_state = location_in_paths(mid, subjects, fill_rule)
        clip_state = location_in_paths(mid, clips, fill_rule)
        in_subject = subject_state == INSIDE
        in_clip = clip_state == INSIDE
        on_subject = subject_state == ON
        on_clip = clip_state == ON
        keep = case clip_type
               when UNION
                 if clips.any? || union_boundary_all
                   union_boundary_fragment?(fragment, subjects, clips, fill_rule)
                 else
                   fragment.source == :subject ? (!in_clip && !on_clip) : (!in_subject && !on_subject)
                 end
               when INTERSECTION
                 fragment.source == :subject ? (in_clip || on_clip) : in_subject
               when DIFFERENCE
                 fragment.source == :subject ? (!in_clip && !on_clip) : (in_subject && !on_subject)
               when XOR
                 fragment.source == :subject ? (!in_clip && !on_clip) : (!in_subject && !on_subject)
               when NO_CLIP
                 fragment.source == :subject
               else
                 raise Error, "unknown clip type #{clip_type.inspect}"
               end
        return nil unless keep
        clip_type == DIFFERENCE && fragment.source == :clip ? EdgeFragment.new(a: fragment.b, b: fragment.a, source: fragment.source) : fragment
      end

      def location_in_paths(point, paths, fill_rule)
        return OUTSIDE if paths.empty?
        return ON if paths.any? { |path| Clipper2.point_in_polygon(point, path) == ON }
        Clipper2.point_in_paths(point, paths, fill_rule) ? INSIDE : OUTSIDE
      end

      def union_boundary_fragment?(fragment, subjects, clips, fill_rule)
        all_paths = subjects + clips
        ax = fragment.a.x.to_f
        ay = fragment.a.y.to_f
        bx = fragment.b.x.to_f
        by = fragment.b.y.to_f
        mx = (ax + bx) / 2.0
        my = (ay + by) / 2.0
        dx = bx - ax
        dy = by - ay
        len = Math.hypot(dx, dy)
        return false if len <= EPSILON
        nx = -dy / len
        ny = dx / len
        eps = 2.0
        p_plus = Point64.new(x: (mx + nx * eps).round, y: (my + ny * eps).round)
        p_minus = Point64.new(x: (mx - nx * eps).round, y: (my - ny * eps).round)
        c_plus = Clipper2.point_in_paths(p_plus, all_paths, fill_rule)
        c_minus = Clipper2.point_in_paths(p_minus, all_paths, fill_rule)
        c_plus != c_minus
      end

      def stitch(fragments, point_class)
        buckets = {}
        fragments.each do |fragment|
          key = point_key(fragment.a)
          buckets[key] ||= []
          buckets[key] << fragment
        end
        paths = []
        until buckets.empty?
          start_key, list = buckets.find { |_key, values| !values.empty? }
          fragment = list.pop
          buckets.delete(start_key) if list.empty?
          start_point = fragment.a
          path = [coerce_point(fragment.a, point_class), coerce_point(fragment.b, point_class)]
          current = fragment.b
          guard = 0
          until same_point?(current, start_point) || guard > fragments.length + 5
            guard += 1
            key = point_key(current)
            candidates = buckets[key]
            break if candidates.nil? || candidates.empty?
            nxt = choose_next(path[-2], current, candidates)
            candidates.delete(nxt)
            buckets.delete(key) if candidates.empty?
            current = nxt.b
            path << coerce_point(current, point_class)
          end
          path.pop if path.length > 1 && same_point?(path[0], path[-1])
          path = Clipper2.clean_path(path)
          paths << path if path.length >= 3
        end
        paths = paths.flat_map { |path| split_at_single_pinched_vertex(path) }
        paths.sort_by { |path| [-Clipper2.area(path).abs, path.first.x, path.first.y] }
      end

      def split_at_single_pinched_vertex(path)
        return [path] if path.length < 6
        dup_pair = nil
        path.each_with_index do |pa, i|
          path.each_with_index do |pb, j|
            next unless j > i
            next unless same_point?(pa, pb)
            dup_pair = [i, j]
            break
          end
          break if dup_pair
        end
        return [path] unless dup_pair
        i, j = dup_pair
        return [path] if (j - i) < 2
        poly1 = path[i...j]
        poly2 = path[j..-1] + path[0...i]
        [poly1, poly2].select { |p| p.length >= 3 }
      end

      def choose_next(previous, current, candidates)
        base = Math.atan2(current.y - previous.y, current.x - previous.x)
        candidates.max_by do |fragment|
          angle = Math.atan2(fragment.b.y - fragment.a.y, fragment.b.x - fragment.a.x) - base
          angle += Math::PI * 2 while angle <= 0
          angle
        end
      end

      def coerce_point(point, point_class)
        if point_class == PointD
          PointD.new(x: point.x, y: point.y, z: point.z)
        else
          Point64.new(x: point.x.round, y: point.y.round, z: point.z)
        end
      end

      def point_key(point)
        x = point.x
        y = point.y
        if x.is_a?(Integer) && y.is_a?(Integer)
          "#{x}:#{y}"
        else
          "#{(x.to_f * 1_000_000_000).round}:#{(y.to_f * 1_000_000_000).round}"
        end
      end

      def same_point?(a, b)
        (a.x - b.x).abs <= EPSILON && (a.y - b.y).abs <= EPSILON
      end
    end
  end

  EdgeFragment = Struct.new(:a, :b, :source, keyword_init: true)

  module_function

  def boolean_op(clip_type, subjects, clips, fill_rule = NON_ZERO)
    clipper = Clipper64.new
    clipper.add_subjects(subjects)
    clipper.add_clips(clips)
    clipper.execute(clip_type, fill_rule)
  end

  def intersect(subjects, clips, fill_rule = NON_ZERO)
    boolean_op(INTERSECTION, subjects, clips, fill_rule)
  end

  def union(subjects, clips = [], fill_rule = NON_ZERO)
    boolean_op(UNION, subjects, clips, fill_rule)
  end

  def difference(subjects, clips, fill_rule = NON_ZERO)
    boolean_op(DIFFERENCE, subjects, clips, fill_rule)
  end

  def xor(subjects, clips, fill_rule = NON_ZERO)
    boolean_op(XOR, subjects, clips, fill_rule)
  end

  def merge_contours_union(paths, fill_rule = NON_ZERO)
    paths = paths.map { |p| Clipper2.path64(p) }
    BooleanEngine.execute(paths, [], UNION, fill_rule, point_class: Point64, union_boundary_all: true)
  end

  def boolean_op_d(clip_type, subjects, clips, fill_rule = NON_ZERO, precision = 2)
    clipper = ClipperD.new(precision)
    clipper.add_subjects(subjects)
    clipper.add_clips(clips)
    clipper.execute(clip_type, fill_rule)
  end

  def minkowski_sum(pattern, path, path_is_closed = true)
    pattern = path64(pattern)
    path = path64(path)
    union(minkowski_quads(pattern, path, false, path_is_closed), [], NON_ZERO)
  end

  def minkowski_diff(pattern, path, path_is_closed = true)
    pattern = path64(pattern)
    path = path64(path)
    union(minkowski_quads(pattern, path, true, path_is_closed), [], NON_ZERO)
  end

  def minkowski_quads(pattern, path, difference, path_is_closed)
    pattern = path64(pattern)
    path = path64(path)
    pat_len = pattern.length
    path_len = path.length
    return [] if pat_len.zero? || path_len.zero?

    delta = path_is_closed ? 0 : 1
    tmp =
      if difference
        path.map do |p|
          pattern.map do |pt2|
            Point64.new(x: p.x - pt2.x, y: p.y - pt2.y, z: p.z)
          end
        end
      else
        path.map do |p|
          pattern.map do |pt2|
            Point64.new(x: p.x + pt2.x, y: p.y + pt2.y, z: p.z)
          end
        end
      end

    result = []
    g = path_is_closed ? path_len - 1 : 0
    h = pat_len - 1
    (delta...path_len).each do |i|
      pat_len.times do |j|
        quad = [tmp[g][h], tmp[i][h], tmp[i][j], tmp[g][j]]
        quad.reverse! unless is_positive(quad)
        result << quad
        h = j
      end
      g = i
    end
    result
  end
end
