require_relative "test_helper"

class Clipper2Test < Minitest::Test
  include Clipper2TestHelpers

  def test_area_orientation_and_point_in_polygon
    path = Clipper2.path64(square(0, 0, 10, 10))
    assert_equal 100.0, Clipper2.area(path)
    assert Clipper2.orientation(path)
    assert_equal Clipper2::INSIDE, Clipper2.point_in_polygon(Clipper2.point64(5, 5), path)
    assert_equal Clipper2::ON, Clipper2.point_in_polygon(Clipper2.point64(0, 5), path)
    assert_equal Clipper2::OUTSIDE, Clipper2.point_in_polygon(Clipper2.point64(20, 5), path)
  end

  def test_rect_clip
    result = Clipper2.rect_clip([0, 0, 10, 10], [square(-5, -5, 5, 5)])
    assert_equal [[[0, 0], [5, 0], [5, 5], [0, 5]]], result.map { |path| path.map(&:to_a) }
  end

  def test_rect_clip_lines
    result = Clipper2.rect_clip_lines([0, 0, 10, 10], [[[ -5, 5], [15, 5]]])
    assert_equal [[[0, 5], [10, 5]]], result.map { |path| path.map(&:to_a) }
  end

  def test_intersection
    result = Clipper2.intersect([square(0, 0, 10, 10)], [square(5, 5, 15, 15)])
    assert_equal 1, result.length
    assert_in_delta 25.0, Clipper2.area(result[0]).abs, 0.001
  end

  def test_difference
    result = Clipper2.difference([square(0, 0, 10, 10)], [square(5, 0, 10, 10)])
    assert_equal 1, result.length
    assert_in_delta 50.0, Clipper2.area(result[0]).abs, 0.001
  end

  def test_clipper_d
    result = Clipper2.boolean_op_d(Clipper2::INTERSECTION, [square(0.0, 0.0, 1.0, 1.0)], [square(0.5, 0.5, 1.5, 1.5)], Clipper2::NON_ZERO, 3)
    assert_equal 1, result.length
    assert_in_delta 0.25, Clipper2.area(result[0]).abs, 0.001
  end

  def test_inflate_paths
    result = Clipper2.inflate_paths([square(0, 0, 10, 10)], 2, Clipper2::MITER)
    assert_equal 1, result.length
    assert result[0].length >= 4
    assert Clipper2.area(result[0]).abs > 100
  end

  def test_minkowski_sum
    result = Clipper2.minkowski_sum(square(0, 0, 1, 1), square(0, 0, 2, 2))
    assert !result.empty?
  end

  def test_triangulate
    result = Clipper2.triangulate([square(0, 0, 10, 10)])
    assert_equal 2, result.triangles.length
    assert_in_delta 100.0, result.triangles.sum { |tri| Clipper2.area(tri.to_a).abs }, 0.001
  end
end
