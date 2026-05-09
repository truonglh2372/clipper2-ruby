module Clipper2
  VERSION = "2.0.1"
  CLIPPER2_VERSION = VERSION
  CLIPPER2_HI_PRECISION = false

  FILL_RULE_EVEN_ODD = :even_odd
  FILL_RULE_NON_ZERO = :non_zero
  FILL_RULE_POSITIVE = :positive
  FILL_RULE_NEGATIVE = :negative

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

  POINT_IN_POLYGON_IS_ON = :is_on
  POINT_IN_POLYGON_IS_INSIDE = :is_inside
  POINT_IN_POLYGON_IS_OUTSIDE = :is_outside

  EPSILON = 1.0e-12

  INT64_MAX = 9_223_372_036_854_775_807
  INT64_MIN = -9_223_372_036_854_775_808
  MAX_COORD = INT64_MAX >> 2
  MIN_COORD = -MAX_COORD
  INVALID_COORD_I64 = INT64_MAX

  MAX_DBL = Float::MAX
  MIN_DBL = -Float::MAX

  PI = Math::PI

  CLIPPER2_MAX_DEC_PRECISION = 8

  PRECISION_ERROR_I = 1
  SCALE_ERROR_I = 2
  NON_PAIR_ERROR_I = 4
  UNDEFINED_ERROR_I = 32
  RANGE_ERROR_I = 64

  PRECISION_ERROR_MSG = "Precision exceeds the permitted range"
  RANGE_ERROR_MSG = "Values exceed permitted range"
  SCALE_ERROR_MSG = "Invalid scale (either 0 or too large)"
  NON_PAIR_ERROR_MSG = "There must be 2 values for each coordinate"
  UNDEFINED_ERROR_MSG = "There is an undefined error in Clipper2"

  UINT64_MASK = (1 << 64) - 1

  class Error < StandardError; end
  class RangeError < Error; end
  class Clipper2Exception < Error; end

  UInt128Parts = Struct.new(:lo, :hi, keyword_init: true) do
    def ==(other)
      other.is_a?(UInt128Parts) && lo == other.lo && hi == other.hi
    end
  end
  UInt128Struct = UInt128Parts

  Point64 = Struct.new(:x, :y, :z, keyword_init: true) do
    def initialize(x: 0, y: 0, z: nil)
      super(x: Integer(x), y: Integer(y), z: z.nil? ? nil : Integer(z))
    end

    def ==(other)
      other.is_a?(Point64) && x == other.x && y == other.y
    end

    alias eql? ==

    def hash
      [x, y].hash
    end

    def !=(other)
      !(self == other)
    end

    def -@
      self.class.new(x: -x, y: -y, z: z)
    end

    def +(other)
      self.class.new(x: x + other.x, y: y + other.y, z: z)
    end

    def -(other)
      self.class.new(x: x - other.x, y: y - other.y, z: z)
    end

    def negate!
      self.x = -x
      self.y = -y
      self
    end

    def *(scale)
      s = scale.to_f
      self.class.new(x: (x * s).round, y: (y * s).round, z: z)
    end

    def to_a
      z.nil? ? [x, y] : [x, y, z]
    end
  end

  PointD = Struct.new(:x, :y, :z, keyword_init: true) do
    def initialize(x: 0.0, y: 0.0, z: nil)
      super(x: Float(x), y: Float(y), z: z.nil? ? nil : Float(z))
    end

    def ==(other)
      other.is_a?(PointD) && x == other.x && y == other.y
    end

    alias eql? ==

    def hash
      [x, y].hash
    end

    def !=(other)
      !(self == other)
    end

    def -@
      self.class.new(x: -x, y: -y, z: z)
    end

    def +(other)
      self.class.new(x: x + other.x, y: y + other.y, z: z)
    end

    def -(other)
      self.class.new(x: x - other.x, y: y - other.y, z: z)
    end

    def negate!
      self.x = -x
      self.y = -y
      self
    end

    def *(scale)
      s = scale.to_f
      self.class.new(x: x * s, y: y * s, z: z)
    end

    def to_a
      z.nil? ? [x, y] : [x, y, z]
    end
  end

  INVALID_POINT64 = Point64.new(x: INT64_MAX, y: INT64_MAX)
  INVALID_POINT_D = PointD.new(x: MAX_DBL, y: MAX_DBL)

  Rect64 = Struct.new(:left, :top, :right, :bottom, keyword_init: true) do
    def self.invalid_rect
      new(left: INT64_MAX, top: INT64_MAX, right: INT64_MIN, bottom: INT64_MIN)
    end

    def self.valid_empty
      new(left: 0, top: 0, right: 0, bottom: 0)
    end

    def initialize(left: 0, top: 0, right: 0, bottom: 0)
      super(left: Integer(left), top: Integer(top), right: Integer(right), bottom: Integer(bottom))
    end

    def valid?
      left != INT64_MAX
    end

    def invalid?
      !valid?
    end

    def width
      right - left
    end

    def height
      bottom - top
    end

    def width=(w)
      self.right = left + w
    end

    def height=(h)
      self.bottom = top + h
    end

    def is_empty?
      bottom <= top || right <= left
    end

    def midpoint
      Point64.new(x: (left + right) / 2, y: (top + bottom) / 2)
    end

    def contains_pt_strict?(point)
      point.x > left && point.x < right && point.y > top && point.y < bottom
    end

    def contains_rect?(other)
      other.left >= left && other.right <= right && other.top >= top && other.bottom <= bottom
    end

    def intersects?(other)
      [left, other.left].max <= [right, other.right].min &&
        [top, other.top].max <= [bottom, other.bottom].min
    end

    def scale!(factor)
      f = factor.to_f
      self.left = (left * f).round
      self.top = (top * f).round
      self.right = (right * f).round
      self.bottom = (bottom * f).round
      self
    end

    def ==(other)
      other.is_a?(Rect64) && left == other.left && right == other.right && top == other.top && bottom == other.bottom
    end

    alias eql? ==

    def +(other)
      Rect64.new(
        left: [left, other.left].min,
        top: [top, other.top].min,
        right: [right, other.right].max,
        bottom: [bottom, other.bottom].max
      )
    end

    def as_path
      [
        Point64.new(x: left, y: top),
        Point64.new(x: right, y: top),
        Point64.new(x: right, y: bottom),
        Point64.new(x: left, y: bottom)
      ]
    end

    alias contains_point? contains_pt_strict?
  end

  RectD = Struct.new(:left, :top, :right, :bottom, keyword_init: true) do
    def self.invalid_rect
      new(left: MAX_DBL, top: MAX_DBL, right: MIN_DBL, bottom: MIN_DBL)
    end

    def initialize(left: 0.0, top: 0.0, right: 0.0, bottom: 0.0)
      super(left: Float(left), top: Float(top), right: Float(right), bottom: Float(bottom))
    end

    def valid?
      left != MAX_DBL
    end

    def invalid?
      !valid?
    end

    def width
      right - left
    end

    def height
      bottom - top
    end

    def width=(w)
      self.right = left + w
    end

    def height=(h)
      self.bottom = top + h
    end

    def is_empty?
      bottom <= top || right <= left
    end

    def midpoint
      PointD.new(x: (left + right) / 2.0, y: (top + bottom) / 2.0)
    end

    def contains_pt_strict?(point)
      point.x > left && point.x < right && point.y > top && point.y < bottom
    end

    def contains_rect?(other)
      other.left >= left && other.right <= right && other.top >= top && other.bottom <= bottom
    end

    def intersects?(other)
      [left, other.left].max <= [right, other.right].min &&
        [top, other.top].max <= [bottom, other.bottom].min
    end

    def scale!(factor)
      f = factor.to_f
      self.left *= f
      self.top *= f
      self.right *= f
      self.bottom *= f
      self
    end

    def ==(other)
      other.is_a?(RectD) && left == other.left && right == other.right && top == other.top && bottom == other.bottom
    end

    alias eql? ==

    def +(other)
      RectD.new(
        left: [left, other.left].min,
        top: [top, other.top].min,
        right: [right, other.right].max,
        bottom: [bottom, other.bottom].max
      )
    end

    def as_path
      [
        PointD.new(x: left, y: top),
        PointD.new(x: right, y: top),
        PointD.new(x: right, y: bottom),
        PointD.new(x: left, y: bottom)
      ]
    end

    alias contains_point? contains_pt_strict?
  end

  INVALID_RECT64 = Rect64.invalid_rect
  INVALID_RECT_D = RectD.invalid_rect

  PolyPath = Struct.new(:polygon, :children, :parent, keyword_init: true) do
    def initialize(polygon: [], children: [], parent: nil)
      super(polygon: polygon, children: children, parent: parent)
    end

    def add_child(path)
      child = path.is_a?(PolyPath) ? path : PolyPath.new(polygon: path)
      child.parent = self
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

    alias child []

    def level
      n = 0
      p = parent
      while p
        n += 1
        p = p.parent
      end
      n
    end

    def hole?
      lvl = level
      lvl != 0 && lvl.even?
    end

    alias is_hole? hole?

    def parent_poly
      parent
    end

    def subtree_area
      Clipper2.area(polygon) + children.sum(&:subtree_area)
    end

    def clear_children
      children.clear
    end
  end

  PolyTree = Class.new(PolyPath)

  module_function

  def max_coord
    MAX_COORD.to_f
  end

  def min_coord
    MIN_COORD.to_f
  end

  def do_error(error_code)
    msg =
      case error_code
      when PRECISION_ERROR_I then PRECISION_ERROR_MSG
      when SCALE_ERROR_I then SCALE_ERROR_MSG
      when NON_PAIR_ERROR_I then NON_PAIR_ERROR_MSG
      when UNDEFINED_ERROR_I then UNDEFINED_ERROR_MSG
      when RANGE_ERROR_I then RANGE_ERROR_MSG
      else "Unknown error"
      end
    raise Clipper2Exception, msg
  end

  def tri_sign(x)
    xi = x.to_i
    (xi.positive? ? 1 : 0) - (xi.negative? ? 1 : 0)
  end

  def multiply_uint64(a, b)
    a = a.to_i & UINT64_MASK
    b = b.to_i & UINT64_MASK
    lo32 = ->(x) { x & 0xffffffff }
    hi32 = ->(x) { x >> 32 }
    x1 = lo32.call(a) * lo32.call(b)
    x2 = hi32.call(a) * lo32.call(b) + hi32.call(x1)
    x3 = lo32.call(a) * hi32.call(b) + lo32.call(x2)
    lo = ((lo32.call(x3) << 32) | lo32.call(x1)) & UINT64_MASK
    hi = (hi32.call(a) * hi32.call(b) + hi32.call(x2) + hi32.call(x3)) & UINT64_MASK
    UInt128Parts.new(lo: lo, hi: hi)
  end

  def products_are_equal(a, b, c, d)
    if [a, b, c, d].any? { |v| v.is_a?(Float) }
      ((a.to_f * b.to_f) - (c.to_f * d.to_f)).abs <= EPSILON
    else
      Integer(a) * Integer(b) == Integer(c) * Integer(d)
    end
  end

  def cross_product_sign(pt1, pt2, pt3)
    a = pt2.x - pt1.x
    b = pt3.y - pt2.y
    c = pt2.y - pt1.y
    d = pt3.x - pt2.x
    ab = Integer(a) * Integer(b)
    cd = Integer(c) * Integer(d)
    return 1 if ab > cd
    return -1 if ab < cd
    0
  end

  def sqr(val)
    vf = val.to_f
    vf * vf
  end

  def near_equal?(p1, p2, max_dist_sqrd)
    sqr(p1.x - p2.x) + sqr(p1.y - p2.y) < max_dist_sqrd
  end

  def mid_point(p1, p2)
    if p1.is_a?(Point64) && p2.is_a?(Point64)
      Point64.new(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    else
      PointD.new(x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0)
    end
  end

  def invalid_rect64
    Rect64.invalid_rect
  end

  def invalid_rect_d
    RectD.invalid_rect
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

  def path_append(path, point)
    path << point
    path
  end

  def paths_append(paths, path)
    paths << path
    paths
  end

  def get_bounds_path(path)
    return Rect64.invalid_rect if path.nil? || path.empty?
    xmin = INT64_MAX
    ymin = INT64_MAX
    xmax = INT64_MIN
    ymax = INT64_MIN
    path.each do |p|
      xmin = p.x if p.x < xmin
      xmax = p.x if p.x > xmax
      ymin = p.y if p.y < ymin
      ymax = p.y if p.y > ymax
    end
    Rect64.new(left: xmin, top: ymin, right: xmax, bottom: ymax)
  end

  def get_bounds_paths(paths)
    return Rect64.invalid_rect if paths.nil? || paths.empty?
    xmin = INT64_MAX
    ymin = INT64_MAX
    xmax = INT64_MIN
    ymax = INT64_MIN
    paths.each do |path|
      path.each do |p|
        xmin = p.x if p.x < xmin
        xmax = p.x if p.x > xmax
        ymin = p.y if p.y < ymin
        ymax = p.y if p.y > ymax
      end
    end
    Rect64.new(left: xmin, top: ymin, right: xmax, bottom: ymax)
  end

  def get_bounds_path_as(left_type, path)
    return Rect64.invalid_rect if path.nil? || path.empty?
    xmin = INT64_MAX
    ymin = INT64_MAX
    xmax = INT64_MIN
    ymax = INT64_MIN
    path.each do |p|
      xmin = [xmin, p.x].min
      xmax = [xmax, p.x].max
      ymin = [ymin, p.y].min
      ymax = [ymax, p.y].max
    end
    left_type.new(left: xmin, top: ymin, right: xmax, bottom: ymax)
  end

  def get_bounds_paths_as(left_type, paths)
    return Rect64.invalid_rect if paths.nil? || paths.empty?
    xmin = INT64_MAX
    ymin = INT64_MAX
    xmax = INT64_MIN
    ymax = INT64_MIN
    paths.each do |path|
      path.each do |p|
        xmin = [xmin, p.x].min
        xmax = [xmax, p.x].max
        ymin = [ymin, p.y].min
        ymax = [ymax, p.y].max
      end
    end
    left_type.new(left: xmin, top: ymin, right: xmax, bottom: ymax)
  end

  def scale_rect(rect, scale)
    s = scale.to_f
    if rect.is_a?(Rect64)
      Rect64.new(
        left: (rect.left * s).round,
        top: (rect.top * s).round,
        right: (rect.right * s).round,
        bottom: (rect.bottom * s).round
      )
    else
      RectD.new(
        left: rect.left * s,
        top: rect.top * s,
        right: rect.right * s,
        bottom: rect.bottom * s
      )
    end
  end

  def scale_path(path, scale_x, scale_y = nil, error_code_holder = nil)
    scale_y = scale_x if scale_y.nil?
    ec = error_code_holder
    sx = scale_x.to_f
    sy = scale_y.to_f
    if sx == 0 || sy == 0
      ec[0] |= SCALE_ERROR_I if ec
      sx = 1.0 if sx == 0
      sy = 1.0 if sy == 0
    end
    path.map do |point|
      Point64.new(x: (point.x * sx).round, y: (point.y * sy).round, z: point.z)
    end
  end

  def scale_paths(paths, scale_x, scale_y = nil, error_code_holder = nil)
    scale_y = scale_x if scale_y.nil?
    ec = error_code_holder || [0]
    sx = scale_x.to_f
    sy = scale_y.to_f
    r = get_bounds_paths_as(RectD, paths)
    unless paths.empty?
      if r.left * sx < min_coord || r.right * sx > max_coord ||
          r.top * sy < min_coord || r.bottom * sy > max_coord
        ec[0] |= RANGE_ERROR_I
        do_error(RANGE_ERROR_I)
        return []
      end
    end
    paths.map { |path| scale_path(path, sx, sy, ec) }
  end

  def transform_path(path)
    path.map { |pt| Point64.new(x: pt.x, y: pt.y, z: pt.respond_to?(:z) ? pt.z : nil) }
  end

  def transform_paths(paths)
    paths.map { |path| transform_path(path) }
  end

  def unscale_path(path, scale)
    path.map { |point| PointD.new(x: point.x.to_f / scale, y: point.y.to_f / scale, z: point.z) }
  end

  def unscale_paths(paths, scale)
    paths.map { |path| unscale_path(path, scale) }
  end

  def strip_near_equal(path, max_dist_sqrd, is_closed_path)
    return [] if path.empty?
    result = []
    path_iter = 0
    first_pt = path[0]
    path_iter += 1
    last_pt = first_pt
    result << first_pt
    while path_iter < path.length
      pt = path[path_iter]
      unless near_equal?(pt, last_pt, max_dist_sqrd)
        last_pt = pt
        result << last_pt
      end
      path_iter += 1
    end
    unless is_closed_path
      return result
    end
    while result.length > 1 && near_equal?(result[-1], first_pt, max_dist_sqrd)
      result.pop
    end
    result
  end

  def strip_near_equal_paths(paths, max_dist_sqrd, is_closed_path)
    paths.map { |path| strip_near_equal(path, max_dist_sqrd, is_closed_path) }
  end

  def strip_duplicates!(path, is_closed_path)
    outp = []
    path.each do |pt|
      outp << pt if outp.empty? || outp[-1].x != pt.x || outp[-1].y != pt.y
    end
    if is_closed_path
      outp.pop while outp.length > 1 && outp[-1].x == outp[0].x && outp[-1].y == outp[0].y
    end
    path.replace(outp)
    path
  end

  def strip_duplicates_paths!(paths, is_closed_path)
    paths.each { |path| strip_duplicates!(path, is_closed_path) }
    paths
  end

  def check_precision_range(precision, error_code_holder = nil)
    ec = error_code_holder || [0]
    if precision >= -CLIPPER2_MAX_DEC_PRECISION && precision <= CLIPPER2_MAX_DEC_PRECISION
      return precision
    end
    ec[0] |= PRECISION_ERROR_I
    precision.clamp(-CLIPPER2_MAX_DEC_PRECISION, CLIPPER2_MAX_DEC_PRECISION)
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
      next unless point.respond_to?(:x)
      raise RangeError, RANGE_ERROR_MSG if point.x.abs > MAX_COORD || point.y.abs > MAX_COORD
    end
  end

  def cross(a, b, c)
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
  end

  def cross_product(pt1, pt2, pt3)
    (pt2.x - pt1.x).to_f * (pt3.y - pt2.y).to_f - (pt2.y - pt1.y).to_f * (pt3.x - pt2.x).to_f
  end

  def cross_product_vecs(vec1, vec2)
    vec1.y.to_f * vec2.x.to_f - vec2.y.to_f * vec1.x.to_f
  end

  def dot(a, b, c)
    (b.x - a.x) * (c.x - a.x) + (b.y - a.y) * (c.y - a.y)
  end

  def dot_product(pt1, pt2, pt3)
    (pt2.x - pt1.x).to_f * (pt3.x - pt2.x).to_f + (pt2.y - pt1.y).to_f * (pt3.y - pt2.y).to_f
  end

  def dot_product_vecs(vec1, vec2)
    vec1.x.to_f * vec2.x.to_f + vec1.y.to_f * vec2.y.to_f
  end

  def distance(a, b)
    Math.hypot(b.x - a.x, b.y - a.y)
  end

  def distance_sq(a, b)
    dx = b.x - a.x
    dy = b.y - a.y
    dx * dx + dy * dy
  end

  alias distance_sqr distance_sq

  def perpendic_dist_from_line_sqrd(pt, line1, line2)
    a = (pt.x - line1.x).to_f
    b = (pt.y - line1.y).to_f
    c = (line2.x - line1.x).to_f
    d = (line2.y - line1.y).to_f
    return 0.0 if c == 0 && d == 0
    sqr(a * d - c * b) / (c * c + d * d)
  end

  def length(path)
    path.each_cons(2).sum { |a, b| distance(a, b) }
  end

  def area(path)
    return 0.0 if path.length < 3
    cnt = path.length
    a = 0.0
    it2 = cnt - 1
    stop = cnt.even? ? it2 : it2 - 1
    it1 = 0
    while it1 < stop
      a += (path[it2].y + path[it1].y).to_f * (path[it2].x - path[it1].x).to_f
      it2 = it1 + 1
      a += (path[it1].y + path[it2].y).to_f * (path[it1].x - path[it2].x).to_f
      it1 += 2
    end
    if cnt.odd?
      a += (path[it2].y + path[it1].y).to_f * (path[it2].x - path[it1].x).to_f
    end
    a * 0.5
  end

  def areas(paths)
    paths.sum { |path| area(path) }
  end

  def is_positive(path)
    area(path) >= 0
  end

  def orientation(path)
    is_positive(path)
  end

  def reverse_path(path)
    path.reverse
  end

  def reverse_paths(paths)
    paths.map(&:reverse)
  end

  def bounds(paths)
    pts = paths.flatten
    return Rect64.valid_empty if pts.empty?
    left = pts.map(&:x).min
    right = pts.map(&:x).max
    top = pts.map(&:y).min
    bottom = pts.map(&:y).max
    klass = pts.any? { |point| point.is_a?(PointD) } ? RectD : Rect64
    klass.new(left: left, top: top, right: right, bottom: bottom)
  end

  alias get_bounds bounds

  def get_line_intersect_pt(ln1a, ln1b, ln2a, ln2b)
    if CLIPPER2_HI_PRECISION
      ln1dy = (ln1b.y - ln1a.y).to_f
      ln1dx = (ln1a.x - ln1b.x).to_f
      ln2dy = (ln2b.y - ln2a.y).to_f
      ln2dx = (ln2a.x - ln2b.x).to_f
      det = (ln2dy * ln1dx) - (ln1dy * ln2dx)
      return [false, nil] if det == 0.0
      bb0minx = [ln1a.x, ln1b.x].min
      bb0miny = [ln1a.y, ln1b.y].min
      bb0maxx = [ln1a.x, ln1b.x].max
      bb0maxy = [ln1a.y, ln1b.y].max
      bb1minx = [ln2a.x, ln2b.x].min
      bb1miny = [ln2a.y, ln2b.y].min
      bb1maxx = [ln2a.x, ln2b.x].max
      bb1maxy = [ln2a.y, ln2b.y].max
      if ln1a.is_a?(Point64)
        originx = ([bb0maxx, bb1maxx].min + [bb0minx, bb1minx].max) >> 1
        originy = ([bb0maxy, bb1maxy].min + [bb0miny, bb1miny].max) >> 1
        ln0c = (ln1dy * (ln1a.x - originx)) + (ln1dx * (ln1a.y - originy))
        ln1c = (ln2dy * (ln2a.x - originx)) + (ln2dx * (ln2a.y - originy))
        hitx = ((ln1dx * ln1c) - (ln2dx * ln0c)) / det
        hity = ((ln2dy * ln0c) - (ln1dy * ln1c)) / det
        ip = Point64.new(x: originx + hitx.round, y: originy + hity.round, z: ln1a.z)
        return [true, ip]
      end
      originx = ([bb0maxx, bb1maxx].min + [bb0minx, bb1minx].max) / 2.0
      originy = ([bb0maxy, bb1maxy].min + [bb0miny, bb1miny].max) / 2.0
      ln0c = (ln1dy * (ln1a.x - originx)) + (ln1dx * (ln1a.y - originy))
      ln1c = (ln2dy * (ln2a.x - originx)) + (ln2dx * (ln2a.y - originy))
      hitx = ((ln1dx * ln1c) - (ln2dx * ln0c)) / det
      hity = ((ln2dy * ln0c) - (ln1dy * ln1c)) / det
      ip = PointD.new(x: originx + hitx, y: originy + hity, z: ln1a.z)
      return [true, ip]
    end
    dx1 = (ln1b.x - ln1a.x).to_f
    dy1 = (ln1b.y - ln1a.y).to_f
    dx2 = (ln2b.x - ln2a.x).to_f
    dy2 = (ln2b.y - ln2a.y).to_f
    det = dy1 * dx2 - dy2 * dx1
    return [false, nil] if det == 0.0
    t = ((ln1a.x - ln2a.x) * dy2 - (ln1a.y - ln2a.y) * dx2) / det
    ip =
      if t <= 0.0
        if ln1a.is_a?(Point64)
          Point64.new(x: ln1a.x, y: ln1a.y, z: ln1a.z)
        else
          PointD.new(x: ln1a.x, y: ln1a.y, z: ln1a.z)
        end
      elsif t >= 1.0
        if ln1b.is_a?(Point64)
          Point64.new(x: ln1b.x, y: ln1b.y, z: ln1b.z)
        else
          PointD.new(x: ln1b.x, y: ln1b.y, z: ln1b.z)
        end
      else
        nx = ln1a.x + t * dx1
        ny = ln1a.y + t * dy1
        if ln1a.is_a?(Point64)
          Point64.new(x: nx.round, y: ny.round, z: ln1a.z)
        else
          PointD.new(x: nx, y: ny, z: ln1a.z)
        end
      end
    [true, ip]
  end

  def translate_point(pt, dx, dy)
    if pt.is_a?(Point64)
      Point64.new(x: (pt.x + dx).round, y: (pt.y + dy).round, z: pt.z)
    else
      PointD.new(x: pt.x + dx, y: pt.y + dy, z: pt.z)
    end
  end

  def reflect_point(pt, pivot)
    if pt.is_a?(Point64)
      Point64.new(x: pivot.x + (pivot.x - pt.x), y: pivot.y + (pivot.y - pt.y), z: pt.z)
    else
      PointD.new(x: pivot.x + (pivot.x - pt.x), y: pivot.y + (pivot.y - pt.y), z: pt.z)
    end
  end

  def get_sign(val)
    return 0 if val == 0
    val > 0 ? 1 : -1
  end

  def segments_intersect(seg1a, seg1b, seg2a, seg2b, inclusive: false)
    dy1 = (seg1b.y - seg1a.y).to_f
    dx1 = (seg1b.x - seg1a.x).to_f
    dy2 = (seg2b.y - seg2a.y).to_f
    dx2 = (seg2b.x - seg2a.x).to_f
    cp = dy1 * dx2 - dy2 * dx1
    return false if cp == 0
    if inclusive
      t = ((seg1a.x - seg2a.x) * dy2 - (seg1a.y - seg2a.y) * dx2)
      return true if t == 0
      if t > 0
        return false if cp < 0 || t > cp
      else
        return false if cp > 0 || t < cp
      end
      t = ((seg1a.x - seg2a.x) * dy1 - (seg1a.y - seg2a.y) * dx1)
      return true if t == 0
      return (cp > 0 && t <= cp) if t > 0
      return (cp < 0 && t >= cp)
    else
      t = ((seg1a.x - seg2a.x) * dy2 - (seg1a.y - seg2a.y) * dx2)
      return false if t == 0
      if t > 0
        return false if cp < 0 || t >= cp
      else
        return false if cp > 0 || t <= cp
      end
      t = ((seg1a.x - seg2a.x) * dy1 - (seg1a.y - seg2a.y) * dx1)
      return false if t == 0
      return (cp > 0 && t < cp) if t > 0
      (cp < 0 && t > cp)
    end
  end

  def get_closest_point_on_segment(off_pt, seg1, seg2)
    return seg1 if seg1.x == seg2.x && seg1.y == seg2.y
    dx = (seg2.x - seg1.x).to_f
    dy = (seg2.y - seg1.y).to_f
    q = ((off_pt.x - seg1.x) * dx + (off_pt.y - seg1.y) * dy) / (sqr(dx) + sqr(dy))
    q = 0.0 if q < 0
    q = 1.0 if q > 1
    if off_pt.is_a?(Point64)
      Point64.new(x: seg1.x + (q * dx).round, y: seg1.y + (q * dy).round, z: off_pt.z)
    else
      PointD.new(x: seg1.x + q * dx, y: seg1.y + q * dy, z: off_pt.z)
    end
  end

  def point_in_polygon_result(pt, polygon)
    return POINT_IN_POLYGON_IS_OUTSIDE if polygon.length < 3
    val = 0
    len = polygon.length
    first = 0
    first += 1 while first < len && polygon[first].y == pt.y
    return POINT_IN_POLYGON_IS_OUTSIDE if first == len
    is_above = polygon[first].y < pt.y
    starting_above = is_above
    curr = first + 1
    cend = len
    cbegin = 0
    loop do
      if curr == cend
        break if cend == first || first == cbegin
        cend = first
        curr = cbegin
      end
      if is_above
        curr += 1 while curr != cend && polygon[curr].y < pt.y
        next if curr == cend
      else
        curr += 1 while curr != cend && polygon[curr].y > pt.y
        next if curr == cend
      end
      prev =
        if curr == cbegin
          polygon[len - 1]
        else
          polygon[curr - 1]
        end
      cur_pt = polygon[curr]
      if cur_pt.y == pt.y
        if cur_pt.x == pt.x ||
            (cur_pt.y == prev.y &&
              ((pt.x < prev.x) != (pt.x < cur_pt.x)))
          return POINT_IN_POLYGON_IS_ON
        end
        curr += 1
        break if curr == first
        next
      end
      if pt.x < cur_pt.x && pt.x < prev.x
      elsif pt.x > prev.x && pt.x > cur_pt.x
        val = 1 - val
      else
        d = cross_product_sign(prev, cur_pt, pt)
        return POINT_IN_POLYGON_IS_ON if d == 0
        val = 1 - val if (d < 0) == is_above
      end
      is_above = !is_above
      curr += 1
    end
    if is_above != starting_above
      cend = len
      curr = cbegin if curr == cend
      prev =
        if curr == cbegin
          polygon[len - 1]
        else
          polygon[curr - 1]
        end
      cur_pt = polygon[curr]
      d = cross_product_sign(prev, cur_pt, pt)
      return POINT_IN_POLYGON_IS_ON if d == 0
      val = 1 - val if (d < 0) == is_above
    end
    val.zero? ? POINT_IN_POLYGON_IS_OUTSIDE : POINT_IN_POLYGON_IS_INSIDE
  end

  def point_in_polygon(point, path)
    case point_in_polygon_result(point, path)
    when POINT_IN_POLYGON_IS_INSIDE then INSIDE
    when POINT_IN_POLYGON_IS_OUTSIDE then OUTSIDE
    when POINT_IN_POLYGON_IS_ON then ON
    end
  end

  def on_segment?(a, b, p)
    cross(a, b, p).abs <= EPSILON && p.x >= [a.x, b.x].min - EPSILON && p.x <= [a.x, b.x].max + EPSILON && p.y >= [a.y, b.y].min - EPSILON && p.y <= [a.y, b.y].max + EPSILON
  end

  def segments_intersect_proper?(a, b, c, d)
    return false if (a.x == c.x && a.y == c.y) || (a.x == d.x && a.y == d.y) || (b.x == c.x && b.y == c.y) || (b.x == d.x && b.y == d.y)
    o1 = cross(a, b, c)
    o2 = cross(a, b, d)
    o3 = cross(c, d, a)
    o4 = cross(c, d, b)
    return true if !o1.zero? && !o2.zero? && !o3.zero? && !o4.zero? && (o1.positive? != o2.positive?) && (o3.positive? != o4.positive?)
    false
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

  def is_collinear?(pt1, shared_pt, pt2)
    a = shared_pt.x - pt1.x
    b = pt2.y - shared_pt.y
    c = shared_pt.y - pt1.y
    d = pt2.x - shared_pt.x
    products_are_equal(a, b, c, d)
  end

  def trim_collinear(path, is_open_path = false)
    pts =
      path.map do |p|
        case p
        when Point64, PointD
          p
        else
          Point64.new(x: p[0], y: p[1], z: p[2])
        end
      end
    len = pts.length
    if len < 3
      return [] if !is_open_path || len < 2 || pts[0] == pts[1]

      return pts.map(&:dup)
    end

    stop_idx = len - 1
    src_it = 0

    unless is_open_path
      while src_it != stop_idx && is_collinear?(pts[stop_idx], pts[src_it], pts[src_it + 1])
        src_it += 1
      end
      while src_it != stop_idx && is_collinear?(pts[stop_idx - 1], pts[stop_idx], pts[src_it])
        stop_idx -= 1
      end
      return [] if src_it == stop_idx
    end

    dst = []
    prev_it = src_it
    src_it += 1
    dst << pts[prev_it]

    while src_it != stop_idx
      unless is_collinear?(pts[prev_it], pts[src_it], pts[src_it + 1])
        prev_it = src_it
        dst << pts[prev_it]
      end
      src_it += 1
    end

    if is_open_path
      dst << pts[src_it]
    elsif !is_collinear?(pts[prev_it], pts[stop_idx], dst[0])
      dst << pts[stop_idx]
    else
      while dst.length > 2 && is_collinear?(dst[-1], dst[-2], dst[0])
        dst.pop
      end
      return [] if dst.length < 3
    end

    dst
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
    simplified = ramer_douglas_peucker(clean_path(path), epsilon)
    return simplified if simplified.length < 3

    trim_collinear(simplified, false)
  end

  def simplify_paths(paths, epsilon = Math.sqrt(2.0))
    paths.map { |path| simplify_path(path, epsilon) }.reject { |path| path.length < 3 }
  end
end
