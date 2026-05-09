require_relative "test_helper"

class UpstreamIsCollinearTest < Minitest::Test
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
    cases.each do |a, b, expected_hi|
      assert_equal expected_hi, Clipper2.multiply_uint64(a, b).hi
      assert_equal expected_hi, Clipper2.multiply_uint64(b, a).hi
    end
  end

  def test_is_collinear_large_coords_not_double_exact
    i = 9_007_199_254_740_993
    pt1 = Clipper2.point64(0, 0)
    shared = Clipper2.point64(i, i * 10)
    pt2 = Clipper2.point64(i * 10, i * 100)
    assert Clipper2.is_collinear?(pt1, shared, pt2)
  end

  def test_is_collinear_union_self_intersecting_even_odd
    i = 0x4000000000000
    subject = Clipper2.path64([[-i, -i], [i, -i], [-i, i], [i, i]])
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects([subject])
    solution = clipper.execute(Clipper2::UNION, Clipper2::EVEN_ODD)
    assert_equal 2, solution.length
  end
end
