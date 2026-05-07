require_relative "core"

module Clipper2
  Triangle = Struct.new(:a, :b, :c, keyword_init: true) do
    def to_a
      [a, b, c]
    end
  end

  TriangulateResult = Struct.new(:triangles, keyword_init: true) do
    def initialize(triangles: [])
      super(triangles: triangles)
    end

    def to_a
      triangles.map(&:to_a)
    end
  end

  module_function

  def triangulate(paths)
    triangles = paths64(paths).flat_map { |path| triangulate_path(path) }
    TriangulateResult.new(triangles: triangles)
  end

  def triangulate_path(path)
    polygon = trim_collinear(path)
    return [] if polygon.length < 3
    polygon = polygon.reverse unless orientation(polygon)
    indices = (0...polygon.length).to_a
    triangles = []
    guard = 0
    while indices.length > 3 && guard < polygon.length * polygon.length
      guard += 1
      ear_index = indices.each_index.find do |i|
        prev_i = indices[(i - 1) % indices.length]
        cur_i = indices[i]
        next_i = indices[(i + 1) % indices.length]
        ear?(polygon, indices, prev_i, cur_i, next_i)
      end
      break if ear_index.nil?
      prev_i = indices[(ear_index - 1) % indices.length]
      cur_i = indices[ear_index]
      next_i = indices[(ear_index + 1) % indices.length]
      triangles << Triangle.new(a: polygon[prev_i], b: polygon[cur_i], c: polygon[next_i])
      indices.delete_at(ear_index)
    end
    if indices.length == 3
      triangles << Triangle.new(a: polygon[indices[0]], b: polygon[indices[1]], c: polygon[indices[2]])
    end
    triangles
  end

  def ear?(polygon, indices, prev_i, cur_i, next_i)
    a = polygon[prev_i]
    b = polygon[cur_i]
    c = polygon[next_i]
    return false if cross(a, b, c) <= EPSILON
    indices.none? do |index|
      next false if index == prev_i || index == cur_i || index == next_i
      point_in_triangle?(polygon[index], a, b, c)
    end
  end

  def point_in_triangle?(p, a, b, c)
    c1 = cross(a, b, p)
    c2 = cross(b, c, p)
    c3 = cross(c, a, p)
    (c1 >= -EPSILON && c2 >= -EPSILON && c3 >= -EPSILON) || (c1 <= EPSILON && c2 <= EPSILON && c3 <= EPSILON)
  end
end
