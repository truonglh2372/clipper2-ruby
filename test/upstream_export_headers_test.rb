require_relative "test_helper"

class UpstreamExportHeadersTest < Minitest::Test
  include Clipper2TestHelpers

  def nested_squares64
    (1..5).map { |i| make_path([-i * 20, -i * 20, i * 20, -i * 20, i * 20, i * 20, -i * 20, i * 20]) }
  end

  def nested_squares_d
    (1..5).map { |i| make_pathd([-i * 20, -i * 20, i * 20, -i * 20, i * 20, i * 20, -i * 20, i * 20]) }
  end

  def export_clip
    [make_path([-90, -120, 90, -120, 90, 120, -90, 120])]
  end

  def test_export_header64
    solution = Clipper2.intersect(nested_squares64, export_clip, Clipper2::EVEN_ODD)
    assert_equal 5, solution.length
  end

  def test_export_header_d
    solution = Clipper2.boolean_op_d(Clipper2::INTERSECTION, nested_squares_d, [make_pathd([-90, -120, 90, -120, 90, 120, -90, 120])], Clipper2::EVEN_ODD, 4)
    assert_equal 5, solution.length
  end

  def test_export_header_tree64
    skip "C export tree serialization is not part of the pure Ruby API"
  end

  def test_export_header_tree_d
    skip "C export tree serialization is not part of the pure Ruby API"
  end
end
