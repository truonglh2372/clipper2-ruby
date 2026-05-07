module Clipper2
  VERSION = "0.1.0"

  INTERSECTION = :intersection
  UNION = :union
  DIFFERENCE = :difference
  XOR = :xor

  EVEN_ODD = :even_odd
  NON_ZERO = :non_zero
  POSITIVE = :positive
  NEGATIVE = :negative

  MITER = :miter
  ROUND = :round
  SQUARE = :square
  BEVEL = :bevel

  POLYGON = :polygon
  JOINED = :joined
  BUTT = :butt
  SQUARE_END = :square_end
  ROUND_END = :round_end

  INSIDE = :inside
  OUTSIDE = :outside
  ON = :on

  EPSILON = 1.0e-12
  MAX_COORD = 4_611_686_018_427_387_903

  UInt128Parts = Struct.new(:hi, :lo, keyword_init: true)

  class Error < StandardError; end
  class RangeError < Error; end

  Point64 = Struct.new(:x, :y, :z, keyword_init: true) do
    def initialize(x: 0, y: 0, z: nil)
      super(x: Integer(x), y: Integer(y), z: z.nil? ? nil : Integer(z))
    end

    def to_a
      z.nil? ? [x, y] : [x, y, z]
    end
  end

  PointD = Struct.new(:x, :y, :z, keyword_init: true) do
    def initialize(x: 0.0, y: 0.0, z: nil)
      super(x: Float(x), y: Float(y), z: z.nil? ? nil : Float(z))
    end

    def to_a
      z.nil? ? [x, y] : [x, y, z]
    end
  end

  Rect64 = Struct.new(:left, :top, :right, :bottom, keyword_init: true) do
    def initialize(left: 0, top: 0, right: 0, bottom: 0)
      super(left: Integer(left), top: Integer(top), right: Integer(right), bottom: Integer(bottom))
    end

    def width
      right - left
    end

    def height
      bottom - top
    end

    def contains_point?(point)
      point.x >= left && point.x <= right && point.y >= top && point.y <= bottom
    end

    def invalid?
      left > right || top > bottom
    end

    def +(other)
      return other if invalid?
      return self if other.invalid?
      Rect64.new(left: [left, other.left].min, top: [top, other.top].min, right: [right, other.right].max, bottom: [bottom, other.bottom].max)
    end

    def as_path
      [
        Point64.new(x: left, y: top),
        Point64.new(x: right, y: top),
        Point64.new(x: right, y: bottom),
        Point64.new(x: left, y: bottom)
      ]
    end
  end

  RectD = Struct.new(:left, :top, :right, :bottom, keyword_init: true) do
    def initialize(left: 0.0, top: 0.0, right: 0.0, bottom: 0.0)
      super(left: Float(left), top: Float(top), right: Float(right), bottom: Float(bottom))
    end

    def width
      right - left
    end

    def height
      bottom - top
    end

    def contains_point?(point)
      point.x >= left && point.x <= right && point.y >= top && point.y <= bottom
    end
  end

  PolyPath = Struct.new(:polygon, :children, keyword_init: true) do
    def initialize(polygon: [], children: [])
      super(polygon: polygon, children: children)
    end

    def add_child(path)
      child = path.is_a?(PolyPath) ? path : PolyPath.new(polygon: path)
      children << child
      child
    end

    def each(&block)
      children.each(&block)
    end

    def count
      children.length
    end

    def [](index)
      children[index]
    end
  end

  PolyTree = Class.new(PolyPath)

  module_function

  def invalid_rect64
    Rect64.new(left: 1, top: 1, right: 0, bottom: 0)
  end

  def multiply_uint64(a, b)
    product = Integer(a) * Integer(b)
    UInt128Parts.new(hi: product >> 64, lo: product & ((1 << 64) - 1))
  end

  def point64(x, y = nil, z = nil)
    return to_point64(x) if y.nil?
    Point64.new(x: x, y: y, z: z)
  end

  def pointd(x, y = nil, z = nil)
    return to_pointd(x) if y.nil?
    PointD.new(x: x, y: y, z: z)
  end

  def to_point64(value, scale: 1)
    case value
    when Point64
      value
    when PointD
      Point64.new(x: (value.x * scale).round, y: (value.y * scale).round, z: value.z)
    when Hash
      Point64.new(x: value[:x] || value["x"], y: value[:y] || value["y"], z: value[:z] || value["z"])
    else
      Point64.new(x: (value[0] * scale).round, y: (value[1] * scale).round, z: value[2])
    end
  end

  def to_pointd(value, scale: 1.0)
    case value
    when PointD
      value
    when Point64
      PointD.new(x: value.x.to_f / scale, y: value.y.to_f / scale, z: value.z)
    when Hash
      PointD.new(x: value[:x] || value["x"], y: value[:y] || value["y"], z: value[:z] || value["z"])
    else
      PointD.new(x: value[0].to_f / scale, y: value[1].to_f / scale, z: value[2])
    end
  end

  def path64(path, scale: 1)
    clean_path(path.map { |point| to_point64(point, scale: scale) })
  end

  def paths64(paths, scale: 1)
    paths.map { |path| path64(path, scale: scale) }.reject(&:empty?)
  end

  def pathd(path, scale: 1.0)
    clean_path(path.map { |point| to_pointd(point, scale: scale) })
  end

  def pathds(paths, scale: 1.0)
    paths.map { |path| pathd(path, scale: scale) }.reject(&:empty?)
  end

  def scale_path(path, scale)
    path.map { |point| Point64.new(x: (point.x * scale).round, y: (point.y * scale).round, z: point.z) }
  end

  def scale_paths(paths, scale)
    paths.map { |path| scale_path(path, scale) }
  end

  def unscale_path(path, scale)
    path.map { |point| PointD.new(x: point.x.to_f / scale, y: point.y.to_f / scale, z: point.z) }
  end

  def unscale_paths(paths, scale)
    paths.map { |path| unscale_path(path, scale) }
  end

  def clean_path(path)
    result = []
    path.each do |point|
      result << point if result.empty? || result[-1].x != point.x || result[-1].y != point.y
    end
    result.pop if result.length > 1 && result[0].x == result[-1].x && result[0].y == result[-1].y
    result
  end

  def check_range!(paths)
    paths.flatten.each do |point|
      raise RangeError, "coordinate outside Clipper2 range" if point.respond_to?(:x) && (point.x.abs > MAX_COORD || point.y.abs > MAX_COORD)
    end
  end

  def cross(a, b, c)
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
  end

  def dot(a, b, c)
    (b.x - a.x) * (c.x - a.x) + (b.y - a.y) * (c.y - a.y)
  end

  def distance(a, b)
    Math.hypot(b.x - a.x, b.y - a.y)
  end

  def distance_sq(a, b)
    dx = b.x - a.x
    dy = b.y - a.y
    dx * dx + dy * dy
  end

  def length(path)
    path.each_cons(2).sum { |a, b| distance(a, b) }
  end

  def area(path)
    return 0.0 if path.length < 3
    sum = 0
    path.each_with_index do |point, index|
      nxt = path[(index + 1) % path.length]
      sum += point.x * nxt.y - nxt.x * point.y
    end
    sum / 2.0
  end

  def areas(paths)
    paths.sum { |path| area(path) }
  end

  def orientation(path)
    area(path) >= 0
  end

  def reverse_path(path)
    path.reverse
  end

  def reverse_paths(paths)
    paths.map(&:reverse)
  end

  def bounds(paths)
    pts = paths.flatten
    return Rect64.new if pts.empty?
    left = pts.map(&:x).min
    right = pts.map(&:x).max
    top = pts.map(&:y).min
    bottom = pts.map(&:y).max
    klass = pts.any? { |point| point.is_a?(PointD) } ? RectD : Rect64
    klass.new(left: left, top: top, right: right, bottom: bottom)
  end

  def on_segment?(a, b, p)
    cross(a, b, p).abs <= EPSILON && p.x >= [a.x, b.x].min - EPSILON && p.x <= [a.x, b.x].max + EPSILON && p.y >= [a.y, b.y].min - EPSILON && p.y <= [a.y, b.y].max + EPSILON
  end

  def point_in_polygon(point, path)
    return OUTSIDE if path.length < 3
    winding = 0
    inside = false
    path.each_with_index do |a, index|
      b = path[(index + 1) % path.length]
      return ON if on_segment?(a, b, point)
      if (a.y > point.y) != (b.y > point.y)
        x = (b.x - a.x) * (point.y - a.y).to_f / (b.y - a.y) + a.x
        inside = !inside if point.x < x
      end
      if a.y <= point.y
        winding += 1 if b.y > point.y && cross(a, b, point) > 0
      elsif b.y <= point.y && cross(a, b, point) < 0
        winding -= 1
      end
    end
    return INSIDE if winding != 0
    inside ? INSIDE : OUTSIDE
  end

  def point_in_paths(point, paths, fill_rule = NON_ZERO)
    case fill_rule
    when EVEN_ODD
      inside = false
      paths.each do |path|
        res = point_in_polygon(point, path)
        return ON if res == ON
        inside = !inside if res == INSIDE
      end
      inside
    when POSITIVE
      winding_number(point, paths) > 0
    when NEGATIVE
      winding_number(point, paths) < 0
    else
      winding_number(point, paths) != 0
    end
  end

  def winding_number(point, paths)
    paths.sum do |path|
      path.each_with_index.sum do |a, index|
        b = path[(index + 1) % path.length]
        if a.y <= point.y
          b.y > point.y && cross(a, b, point) > 0 ? 1 : 0
        else
          b.y <= point.y && cross(a, b, point) < 0 ? -1 : 0
        end
      end
    end
  end

  def is_collinear?(a, b, c)
    cross(a, b, c).abs <= EPSILON
  end

  def trim_collinear(path, preserve_collinear = false)
    result = clean_path(path)
    changed = true
    while changed && result.length > 2
      changed = false
      result.length.times do |index|
        prev = result[(index - 1) % result.length]
        cur = result[index]
        nxt = result[(index + 1) % result.length]
        next unless is_collinear?(prev, cur, nxt)
        next if preserve_collinear && dot(cur, prev, nxt) < 0
        result.delete_at(index)
        changed = true
        break
      end
    end
    result
  end

  def perpendicular_distance(point, line_start, line_end)
    len = distance(line_start, line_end)
    return distance(point, line_start) if len <= EPSILON
    cross(line_start, line_end, point).abs / len
  end

  def ramer_douglas_peucker(path, epsilon)
    return path.dup if path.length < 3
    max_dist = 0.0
    index = 0
    (1...(path.length - 1)).each do |i|
      dist = perpendicular_distance(path[i], path[0], path[-1])
      if dist > max_dist
        index = i
        max_dist = dist
      end
    end
    return [path[0], path[-1]] unless max_dist > epsilon
    left = ramer_douglas_peucker(path[0..index], epsilon)
    right = ramer_douglas_peucker(path[index..], epsilon)
    left[0...-1] + right
  end

  def simplify_path(path, epsilon = Math.sqrt(2.0))
    trim_collinear(ramer_douglas_peucker(clean_path(path), epsilon))
  end

  def simplify_paths(paths, epsilon = Math.sqrt(2.0))
    paths.map { |path| simplify_path(path, epsilon) }.reject { |path| path.length < 3 }
  end
end
