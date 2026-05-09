require_relative "test_helper"

class UpstreamRandomPathsTest < Minitest::Test
  DEFAULT_RANDOM_PATH_ITERS = 150

  CLIP_TYPES_ORDERED = [
    Clipper2::NO_CLIP,
    Clipper2::INTERSECTION,
    Clipper2::UNION,
    Clipper2::DIFFERENCE,
    Clipper2::XOR
  ].freeze

  FILL_RULES_ORDERED = [
    Clipper2::EVEN_ODD,
    Clipper2::NON_ZERO,
    Clipper2::POSITIVE,
    Clipper2::NEGATIVE
  ].freeze

  def generate_random_int(rng, min_value, max_value)
    return min_value if min_value == max_value

    rng.rand(min_value..max_value)
  end

  def generate_random_paths(rng, min_path_count, max_complexity)
    path_count = generate_random_int(rng, min_path_count, max_complexity)
    path_count.times.map do
      path_length = generate_random_int(rng, 0, [0, max_complexity].max)
      path_length.times.each_with_object([]) do |_, acc|
        if acc.empty?
          x = rng.rand((-max_complexity)..(max_complexity * 2))
          y = rng.rand((-max_complexity)..(max_complexity * 2))
          acc << [x, y]
        else
          px, py = acc.last
          dx = rng.rand(-5..5)
          dy = rng.rand(-5..5)
          acc << [px + dx, py + dy]
        end
      end
    end
  end

  def flatten_polypath(pp)
    out = []
    out << pp.polygon if pp.polygon.length >= 3
    pp.children.each { |ch| out.concat(flatten_polypath(ch)) }
    out
  end

  def polytree_to_paths64(tree)
    tree.children.flat_map { |ch| flatten_polypath(ch) }
  end

  def closed_solution_area_i(paths)
    Clipper2.areas(paths).to_i
  end

  def test_random_paths
    rng = Random.new(42)
    iterations =
      if ENV["CLIPPER2_RANDOM_PATHS_ITERS"]
        [ENV["CLIPPER2_RANDOM_PATHS_ITERS"].to_i, 1].max
      else
        DEFAULT_RANDOM_PATH_ITERS
      end

    iterations.times do |i|
      max_complexity = [1, i / 10].max
      subject = generate_random_paths(rng, 1, max_complexity)
      subject_open = generate_random_paths(rng, 0, max_complexity)
      clip = generate_random_paths(rng, 0, max_complexity)
      ct = CLIP_TYPES_ORDERED[generate_random_int(rng, 0, 4)]
      fr = FILL_RULES_ORDERED[generate_random_int(rng, 0, 3)]

      solution = []
      solution_open = []
      c = Clipper2::Clipper64.new
      subject.each { |path| c.add_subject(path) }
      subject_open.each { |path| c.add_open_subject(path) }
      clip.each { |path| c.add_clip(path) }
      assert c.execute_closed_open(ct, fr, solution, solution_open), "execute_closed_open iter=#{i}"
      area_paths = closed_solution_area_i(solution)

      solution_polytree = Clipper2::PolyTree.new
      solution_polytree_open = []
      clipper_polytree = Clipper2::Clipper64.new
      subject.each { |path| clipper_polytree.add_subject(path) }
      subject_open.each { |path| clipper_polytree.add_open_subject(path) }
      clip.each { |path| clipper_polytree.add_clip(path) }
      assert clipper_polytree.execute_polytree_open(ct, fr, solution_polytree, solution_polytree_open), "execute_polytree_open iter=#{i}"
      solution_polytree_paths = polytree_to_paths64(solution_polytree)
      area_polytree = closed_solution_area_i(solution_polytree_paths)

      assert_equal area_paths, area_polytree, "closed area paths vs polytree iter=#{i} ct=#{ct} fr=#{fr}"
    end
  end
end
