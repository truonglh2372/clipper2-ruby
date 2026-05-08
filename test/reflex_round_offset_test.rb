# frozen_string_literal: true

require_relative "test_helper"

class ReflexRoundOffsetTest < Minitest::Test
  def count_on_inset_circle(ring, ax, ay, r, band)
    ring.count { |p| (Math.hypot(p.x - ax, p.y - ay) - r).abs <= band }
  end

  def test_single_reflex_vertex_uses_round_arc_tessellation
    paths = [[[0, 0], [20_000, 400], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    delta = -5000
    arc_tol = 50
    sol = Clipper2.inflate_paths(paths, delta, Clipper2::ROUND, Clipper2::POLYGON, 2.0, arc_tol)
    assert_equal 1, sol.length
    ring = sol[0]
    n = count_on_inset_circle(ring, 20_000, 400, delta.abs, 350)
    assert_operator n, :>=, 3, "expected multiple points on |delta| circle at reflex apex"
  end

  def test_double_reflex_each_gets_arc_samples
    paths = [[
      [0, 0], [10_000, 500], [20_000, 0], [30_000, 500], [40_000, 0],
      [40_000, 50_000], [0, 50_000]
    ]]
    delta = -3000
    arc_tol = 50
    sol = Clipper2.inflate_paths(paths, delta, Clipper2::ROUND, Clipper2::POLYGON, 2.0, arc_tol)
    assert_equal 1, sol.length
    ring = sol[0]
    band = 250
    assert_operator count_on_inset_circle(ring, 10_000, 500, delta.abs, band), :>=, 3
    assert_operator count_on_inset_circle(ring, 30_000, 500, delta.abs, band), :>=, 3
  end
end
