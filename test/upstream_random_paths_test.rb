require_relative "test_helper"

class UpstreamRandomPathsTest < Minitest::Test
  include Clipper2TestHelpers

  def generate_random_int(rng, min_value, max_value)
    return min_value if min_value == max_value
    rng.rand(min_value..max_value)
  end

  def generate_random_paths(rng, min_path_count, max_complexity)
    path_count = generate_random_int(rng, min_path_count, max_complexity)
    Array.new(path_count) do
      path_length = generate_random_int(rng, 0, [0, max_complexity].max)
      path = []
      path_length.times do
        if path.empty?
          path << [rng.rand(-max_complexity..(max_complexity * 2)), rng.rand(-max_complexity..(max_complexity * 2))]
        else
          previous = path[-1]
          path << [previous[0] + rng.rand(-5..5), previous[1] + rng.rand(-5..5)]
        end
      end
      path
    end
  end

  def test_random_paths
    rng = Random.new(42)
    clip_types = [Clipper2::INTERSECTION, Clipper2::UNION, Clipper2::DIFFERENCE, Clipper2::XOR]
    fill_rules = [Clipper2::EVEN_ODD, Clipper2::NON_ZERO, Clipper2::POSITIVE, Clipper2::NEGATIVE]
    10.times do |i|
      max_complexity = [1, i / 10].max
      subject = generate_random_paths(rng, 1, max_complexity)
      clip = generate_random_paths(rng, 0, max_complexity)
      clipper = Clipper2::Clipper64.new
      clipper.add_subjects(subject)
      clipper.add_clips(clip)
      paths = clipper.execute(clip_types[rng.rand(0...clip_types.length)], fill_rules[rng.rand(0...fill_rules.length)])
      tree = clipper.execute_polytree(Clipper2::UNION, Clipper2::NON_ZERO)
      assert_instance_of Array, paths
      assert_instance_of Clipper2::PolyTree, tree
    end
  end
end
