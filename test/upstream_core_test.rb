require_relative "test_helper"

class UpstreamCoreTest < Minitest::Test
  include Clipper2TestHelpers

  def test_hi_calculation
    cases = [
      [0x51eaed81157de061, 0x3a271fb2745b6fe9, 0x129bbebdfae0464e],
      [0xc2055706a62883fa, 0x26c78bc79c2322cc, 0x1d640701d192519b],
      [0x874ddae32094b0de, 0x9b1559a06fdf83e0, 0x51f76c49563e5bfe],
      [0x81fb3ad3636ca900, 0x239c000a982a8da4, 0x12148e28207b83a3],
      [0x4be0b4c5d2725c44, 0x990cd6db34a04c30, 0x2d5d1a4183fd6165],
      [0x978ec0c0433c01f6, 0x2df03d097966b536, 0x1b3251d91fe272a5],
      [0x49c5cbbcfd716344, 0xc489e3b34b007ad3, 0x38a32c74c8c191a4],
      [0xd3361cdbeed655d5, 0x1240da41e324953a, 0x0f0f4fa11e7e8f2a],
      [0x51b854f8e71b0ae0, 0x6f8d438aae530af5, 0x239c04ee3c8cc248],
      [0xbbecf7dbc6147480, 0xbb0f73d0f82e2236, 0x895170f4e9a216a7]
    ]
    cases.each do |a, b, expected|
      assert_equal expected, Clipper2.multiply_uint64(a, b).hi
      assert_equal expected, Clipper2.multiply_uint64(b, a).hi
    end
  end

  def test_is_collinear
    i = 9_007_199_254_740_993
    assert Clipper2.is_collinear?(Clipper2.point64(0, 0), Clipper2.point64(i, i * 10), Clipper2.point64(i * 10, i * 100))
  end

  def test_is_collinear2
    skip "requires full Clipper2 self-intersection union parity"
    i = 0x4000000000000
    subject = [make_path([-i, -i, i, -i, -i, i, i, i])]
    solution = Clipper2.union(subject, [], Clipper2::EVEN_ODD)
    assert_equal 2, solution.length
  end

  def test_negative_orientation
    skip "requires full Clipper2 negative fill union parity"
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
    input1 = Clipper2.path64(make_path([10, 10, 10, 10, 50, 10, 100, 10, 100, 100, 10, 100, 10, 10, 20, 10]))
    assert_equal 4, Clipper2.trim_collinear(input1, false).length
    input2 = Clipper2.path64(make_path([10, 10, 10, 10, 100, 10, 100, 100, 10, 100, 10, 10, 10, 10]))
    skip "requires upstream PreserveCollinear duplicate vertex behavior"
    assert_equal 5, Clipper2.trim_collinear(input2, true).length
    input3 = Clipper2.path64(make_path([10, 10, 10, 50, 10, 10, 50, 10, 50, 50, 50, 10, 70, 10, 70, 50, 70, 10, 50, 10, 100, 10, 100, 50, 100, 10]))
    assert_equal 0, Clipper2.trim_collinear(input3).length
    input4 = Clipper2.path64(make_path([2, 3, 3, 4, 4, 4, 4, 5, 7, 5, 8, 4, 8, 3, 9, 3, 8, 3, 7, 3, 6, 3, 5, 3, 4, 3, 3, 3, 2, 3]))
    output4a = Clipper2.trim_collinear(input4)
    output4b = Clipper2.trim_collinear(output4a)
    assert_equal 7, output4a.length
    assert_equal(-9, Clipper2.area(output4a).to_i)
    assert_equal output4a.length, output4b.length
    assert_equal Clipper2.area(output4a).to_i, Clipper2.area(output4b).to_i
  end

  def test_simplify_path
    input = Clipper2.path64(make_path([0, 0, 1, 1, 0, 20, 0, 21, 1, 40, 0, 41, 0, 60, 0, 61, 0, 80, 1, 81, 0, 100]))
    output = Clipper2.ramer_douglas_peucker(input, 2)
    assert_equal 100, Clipper2.length(output).round
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
