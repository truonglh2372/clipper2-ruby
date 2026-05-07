require_relative "test_helper"

class UpstreamOffsetsTest < Minitest::Test
  include Clipper2TestHelpers

  def test_offsets
    skip "requires upstream Offsets.txt fixture conversion"
  end

  def test_offsets2
    subject = [make_path([50, 50, 100, 50, 100, 150, 50, 150, 0, 100])]
    solution = Clipper2.inflate_paths(subject, 100, Clipper2::ROUND, Clipper2::POLYGON, 2, 2.5)
    assert_equal 1, solution.length
    assert_operator solution[0].length, :>, subject[0].length
  end

  def test_offsets3
    skip "requires exact upstream negative miter cleanup parity"
  end

  def test_offsets4
    paths = [[[0, 0], [20000, 200], [40000, 0], [40000, 50000], [0, 50000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::SQUARE, Clipper2::POLYGON)
    assert_equal 1, solution.length
    assert_operator solution[0].length, :>=, 4
    paths = [[[0, 0], [20000, 400], [40000, 0], [40000, 50000], [0, 50000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::ROUND, Clipper2::POLYGON, 2, 100)
    assert_equal 1, solution.length
    assert_operator solution[0].length, :>, 5
  end

  def test_offsets5
    skip "requires large upstream offset cleanup fixture embedded in C++ test"
  end

  def test_offsets6
    skip "requires large upstream rounded-end offset fixture embedded in C++ test"
  end

  def test_offsets7
    skip "requires upstream issue #593/#715 offset parity"
  end

  def test_offsets8
    skip "requires upstream issue #724 offset parity"
  end

  def test_offsets9
    skip "requires upstream issue #733 offset parity"
  end

  def test_offsets10
    skip "requires upstream issue #715 open path offset parity"
  end

  def test_offsets11
    skip "requires upstream issue #405 offset parity"
  end

  def test_offsets12
    skip "requires upstream issue #873 offset parity"
  end

  def test_offsets13
    skip "requires upstream issue #965 offset parity"
  end
end
