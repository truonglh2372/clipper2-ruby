require_relative "test_helper"

class UpstreamCoreTest < Minitest::Test
  include Clipper2TestHelpers

  def test_negative_orientation
    subjects = [
      make_path([0, 0, 0, 100, 100, 100, 100, 0]),
      make_path([10, 10, 10, 110, 110, 110, 110, 10])
    ]
    clip = [make_path([50, 50, 50, 150, 150, 150, 150, 50])]
    refute Clipper2.orientation(Clipper2.path64(subjects[0]))
    refute Clipper2.orientation(Clipper2.path64(subjects[1]))
    refute Clipper2.orientation(Clipper2.path64(clip[0]))
    solution = Clipper2.union(subjects, clip, Clipper2::NEGATIVE)
    assert_equal 1, solution.length
    assert_equal 12, solution[0].length
  end

  def test_trim_collinear
    input1 = points64([10, 10, 10, 10, 50, 10, 100, 10, 100, 100, 10, 100, 10, 10, 20, 10])
    assert_equal 4, Clipper2.trim_collinear(input1, false).length
    input2 = points64([10, 10, 10, 10, 100, 10, 100, 100, 10, 100, 10, 10, 10, 10])
    assert_equal 5, Clipper2.trim_collinear(input2, true).length
    input3 = points64([10, 10, 10, 50, 10, 10, 50, 10, 50, 50, 50, 10, 70, 10, 70, 50, 70, 10, 50, 10, 100, 10, 100, 50, 100, 10])
    assert_equal 0, Clipper2.trim_collinear(input3).length
    input4 = points64([2, 3, 3, 4, 4, 4, 4, 5, 7, 5, 8, 4, 8, 3, 9, 3, 8, 3, 7, 3, 6, 3, 5, 3, 4, 3, 3, 3, 2, 3])
    output4a = Clipper2.trim_collinear(input4)
    output4b = Clipper2.trim_collinear(output4a)
    assert_equal 7, output4a.length
    assert_equal(-9, Clipper2.area(output4a).to_i)
    assert_equal output4a.length, output4b.length
    assert_equal Clipper2.area(output4a).to_i, Clipper2.area(output4b).to_i
  end

  def test_simplify_path
    input = Clipper2.path64(make_path([0, 0, 1, 1, 0, 20, 0, 21, 1, 40, 0, 41, 0, 60, 0, 61, 0, 80, 1, 81, 0, 100]))
    output = Clipper2.simplify_path(input, 2)
    assert_equal 100, Clipper2.length(output)
    assert_equal 2, output.length
  end

  def test_rect_op_plus
    cases = [
      [Clipper2.invalid_rect64, Clipper2::Rect64.new(left: -1, top: -1, right: 10, bottom: 10), Clipper2::Rect64.new(left: -1, top: -1, right: 10, bottom: 10)],
      [Clipper2.invalid_rect64, Clipper2::Rect64.new(left: 1, top: 1, right: 10, bottom: 10), Clipper2::Rect64.new(left: 1, top: 1, right: 10, bottom: 10)],
      [Clipper2::Rect64.new(left: 0, top: 0, right: 1, bottom: 1), Clipper2::Rect64.new(left: -1, top: -1, right: 0, bottom: 0), Clipper2::Rect64.new(left: -1, top: -1, right: 1, bottom: 1)],
      [Clipper2::Rect64.new(left: -10, top: -10, right: -1, bottom: -1), Clipper2::Rect64.new(left: 1, top: 1, right: 10, bottom: 10), Clipper2::Rect64.new(left: -10, top: -10, right: 10, bottom: 10)]
    ]
    cases.each do |lhs, rhs, expected|
      assert_equal expected, lhs + rhs
      assert_equal expected, rhs + lhs
    end
  end
end
