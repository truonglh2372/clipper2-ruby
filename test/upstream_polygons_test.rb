require_relative "test_helper"

class UpstreamPolygonsTest < Minitest::Test
  include Clipper2TestHelpers

  def test_multiple_polygons
    skip "requires upstream Polygons.txt fixture conversion"
  end

  def test_horz_spikes
    paths = [
      make_path([1600, 0, 1600, 100, 2050, 100, 2050, 300, 450, 300, 450, 0]),
      make_path([1800, 200, 1800, 100, 1600, 100, 2000, 100, 2000, 200])
    ]
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(paths)
    solution = clipper.execute(Clipper2::UNION, Clipper2::NON_ZERO)
    assert_operator solution.length, :>=, 1
  end

  def test_collinear_on_mac_os
    skip "requires full Clipper2 collinear union cleanup parity"
    subject = [
      make_path([0, -453054451, 0, -433253797, -455550000, 0]),
      make_path([0, -433253797, 0, 0, -455550000, 0])
    ]
    clipper = Clipper2::Clipper64.new
    clipper.preserve_collinear = false
    clipper.add_subjects(subject)
    solution = clipper.execute(Clipper2::UNION, Clipper2::NON_ZERO)
    assert_equal 1, solution.length
    assert_equal 3, solution[0].length
    assert_equal Clipper2.orientation(Clipper2.path64(subject[0])), Clipper2.orientation(solution[0])
  end
end
