require_relative "test_helper"

class UpstreamOffsetOrientationTest < Minitest::Test
  include Clipper2TestHelpers

  def test_offsetting_orientation1
    subject = [make_path([0, 0, 0, 5, 5, 5, 5, 0])]
    solution = Clipper2.inflate_paths(subject, 1, Clipper2::ROUND, Clipper2::POLYGON)
    assert_equal 1, solution.length
    assert_equal Clipper2.orientation(Clipper2.path64(subject[0])), Clipper2.orientation(solution[0])
  end

  def test_offsetting_orientation2
    skip "requires exact upstream offset path ordering with ReverseSolution"
    subject = [
      make_path([20, 220, 280, 220, 280, 280, 20, 280]),
      make_path([0, 200, 0, 300, 300, 300, 300, 200])
    ]
    offset = Clipper2::ClipperOffset.new
    offset.reverse_solution = true
    offset.add_paths(subject, Clipper2::ROUND, Clipper2::POLYGON)
    solution = offset.execute(5)
    assert_equal 2, solution.length
    refute_equal Clipper2.orientation(Clipper2.path64(subject[1])), Clipper2.orientation(solution[0])
  end
end
