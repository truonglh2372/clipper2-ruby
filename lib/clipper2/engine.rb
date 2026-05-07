require_relative "core"

module Clipper2
  EdgeFragment = Struct.new(:a, :b, :source, keyword_init: true)

  class ClipperBase
    attr_accessor :preserve_collinear, :reverse_solution

    def initialize
      @subjects = []
      @clips = []
      @open_subjects = []
      @preserve_collinear = false
      @reverse_solution = false
    end

    def clear
      @subjects.clear
      @clips.clear
      @open_subjects.clear
      self
    end

    def add_subject(path)
      @subjects << normalize_path(path)
      self
    end

    def add_subjects(paths)
      paths.each { |path| add_subject(path) }
      self
    end

    def add_clip(path)
      @clips << normalize_path(path)
      self
    end

    def add_clips(paths)
      paths.each { |path| add_clip(path) }
      self
    end

    def add_open_subject(path)
      @open_subjects << normalize_path(path, closed: false)
      self
    end

    def add_open_subjects(paths)
      paths.each { |path| add_open_subject(path) }
      self
    end

    def execute(clip_type, fill_rule = NON_ZERO, solution = nil)
      result = BooleanEngine.execute(@subjects, @clips, clip_type, fill_rule, point_class: point_class)
      result = result.map(&:reverse) if @reverse_solution
      result = result.map { |path| Clipper2.trim_collinear(path, @preserve_collinear) }
      result.reject! { |path| path.length < 3 || Clipper2.area(path).abs <= EPSILON }
      solution.replace(result) if solution.respond_to?(:replace)
      result
    end

    def execute_polytree(clip_type, fill_rule = NON_ZERO)
      tree = PolyTree.new
      execute(clip_type, fill_rule).each { |path| tree.add_child(path) }
      tree
    end

    private

    def point_class
      Point64
    end
  end

  class Clipper64 < ClipperBase
    private

    def normalize_path(path, closed: true)
      result = Clipper2.path64(path)
      closed ? Clipper2.trim_collinear(result, @preserve_collinear) : result
    end

    def point_class
      Point64
    end
  end

  class ClipperD < ClipperBase
    attr_reader :scale

    def initialize(precision = 2)
      super()
      @precision = precision
      @scale = 10**precision
    end

    def execute(clip_type, fill_rule = NON_ZERO, solution = nil)
      subj = @subjects.map { |path| Clipper2.scale_path(path, @scale) }
      clips = @clips.map { |path| Clipper2.scale_path(path, @scale) }
      result = BooleanEngine.execute(subj, clips, clip_type, fill_rule, point_class: Point64)
      result = result.map(&:reverse) if @reverse_solution
      result = Clipper2.unscale_paths(result, @scale)
      solution.replace(result) if solution.respond_to?(:replace)
      result
    end

    private

    def normalize_path(path, closed: true)
      result = Clipper2.pathd(path)
      closed ? Clipper2.trim_collinear(result, @preserve_collinear) : result
    end

    def point_class
      PointD
    end
  end

  class BooleanEngine
    class << self
      def execute(subjects, clips, clip_type, fill_rule, point_class:)
        subjects = subjects.map { |path| Clipper2.clean_path(path) }.reject { |path| path.length < 3 }
        clips = clips.map { |path| Clipper2.clean_path(path) }.reject { |path| path.length < 3 }
        return subjects.map(&:dup) if clips.empty? && [UNION, DIFFERENCE, XOR].include?(clip_type)
        return [] if subjects.empty? || ([INTERSECTION, DIFFERENCE].include?(clip_type) && clips.empty?)
        fragments = split_fragments(subjects, clips)
        selected = fragments.filter_map { |fragment| select_fragment(fragment, subjects, clips, clip_type, fill_rule) }
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
            next if edge_a[:source] == edge_b[:source] && edge_a[:path_index] == edge_b[:path_index]
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
        path.each_with_index do |point, index|
          edges << { a: point, b: path[(index + 1) % path.length], source: source, path_index: path_index }
        end
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

      def select_fragment(fragment, subjects, clips, clip_type, fill_rule)
        mid = midpoint(fragment)
        subject_state = location_in_paths(mid, subjects, fill_rule)
        clip_state = location_in_paths(mid, clips, fill_rule)
        in_subject = subject_state == INSIDE
        in_clip = clip_state == INSIDE
        on_subject = subject_state == ON
        on_clip = clip_state == ON
        keep = case clip_type
               when UNION
                 fragment.source == :subject ? (!in_clip && !on_clip) : (!in_subject && !on_subject)
               when INTERSECTION
                 fragment.source == :subject ? (in_clip || on_clip) : in_subject
               when DIFFERENCE
                 fragment.source == :subject ? (!in_clip && !on_clip) : (in_subject && !on_subject)
               when XOR
                 fragment.source == :subject ? (!in_clip && !on_clip) : (!in_subject && !on_subject)
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
        paths.sort_by { |path| [-Clipper2.area(path).abs, path.first.x, path.first.y] }
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
        "#{(point.x.to_f * 1_000_000_000).round}:#{(point.y.to_f * 1_000_000_000).round}"
      end

      def same_point?(a, b)
        (a.x - b.x).abs <= EPSILON && (a.y - b.y).abs <= EPSILON
      end
    end
  end

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

  def boolean_op_d(clip_type, subjects, clips, fill_rule = NON_ZERO, precision = 2)
    clipper = ClipperD.new(precision)
    clipper.add_subjects(subjects)
    clipper.add_clips(clips)
    clipper.execute(clip_type, fill_rule)
  end
end
