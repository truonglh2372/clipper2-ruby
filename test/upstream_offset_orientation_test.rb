require_relative "test_helper"

class UpstreamOffsetOrientationTest < Minitest::Test
  include Clipper2TestHelpers

  def test_offsetting_orientation1
    subject = [make_path([100, 100, 200, 100, 200, 400, 100, 400])]
    solution = Clipper2.inflate_paths(subject, 50, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.length
    subj0 = Clipper2.path64(subject[0])
    assert_equal Clipper2.is_positive(subj0), Clipper2.is_positive(solution[0])
  end

  def test_offsetting_orientation2
    subject = [
      make_path([20, 220, 280, 220, 280, 280, 20, 280]),
      make_path([0, 200, 0, 300, 300, 300, 300, 200])
    ]
    offset = Clipper2::ClipperOffset.new
    offset.reverse_solution = true
    offset.add_paths(subject, Clipper2::ROUND, Clipper2::POLYGON)
    solution = offset.execute(5)
    assert_equal 2, solution.length
    subj1 = Clipper2.path64(subject[1])
    refute(solution.all? { |p| Clipper2.is_positive(p) == Clipper2.is_positive(subj1) })
  end
end
