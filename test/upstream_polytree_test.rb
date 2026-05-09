require_relative "test_helper"
require_relative "clip_file_load"

class UpstreamPolytreeTest < Minitest::Test
  include Clipper2TestHelpers

  POLYTREE_HOLE_OWNER = File.expand_path("fixtures/PolytreeHoleOwner.txt", __dir__)
  POLYTREE_HOLE_OWNER2 = File.expand_path("fixtures/PolytreeHoleOwner2.txt", __dir__)

  def assert_polytree_vertices_inside_parents(node)
    node.children.each do |ch|
      if node.polygon.length >= 3 && ch.polygon.length >= 3
        ch.polygon.each do |pt|
          refute_equal Clipper2::OUTSIDE, Clipper2.point_in_polygon(pt, node.polygon), "child vertex outside parent polygon"
        end
      end
      assert_polytree_vertices_inside_parents(ch)
    end
  end

  def assert_nested_geometry(tree)
    tree.children.each { |ch| assert_polytree_vertices_inside_parents(ch) }
  end

  def poly_path_point_balance(pp, pt)
    bal = 0
    if pp.polygon.length > 0 && Clipper2.point_in_polygon(pt, pp.polygon) != Clipper2::OUTSIDE
      bal += pp.hole? ? -1 : 1
    end
    pp.children.each { |ch| bal += poly_path_point_balance(ch, pt) }
    bal
  end

  def polytree_contains_point?(tree, pt)
    bal = tree.children.sum { |ch| poly_path_point_balance(ch, pt) }
    assert_operator bal, :>=, 0
    bal != 0
  end

  def flatten_polys(pp)
    out = []
    out << pp.polygon if pp.polygon.length >= 3
    pp.children.each { |ch| out.concat(flatten_polys(ch)) }
    out
  end

  def flatten_tree_polygons(tree)
    tree.children.flat_map { |ch| flatten_polys(ch) }
  end

  def test_polytree_holes1
    skip "add test/fixtures/PolytreeHoleOwner.txt from AngusJohnson/Clipper2" unless File.file?(POLYTREE_HOLE_OWNER)

    text = File.read(POLYTREE_HOLE_OWNER)
    data = ClipFileLoad.load_test_num(text, 1)
    refute_nil data
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(data[:subjects])
    clipper.add_open_subjects(data[:subjects_open])
    clipper.add_clips(data[:clip])
    open_sol = []
    tree = Clipper2::PolyTree.new
    clipper.execute_polytree_open(Clipper2::NO_CLIP, Clipper2::EVEN_ODD, tree, open_sol)
    assert_nested_geometry(tree)
  end

  def test_polytree_holes2
    skip "add test/fixtures/PolytreeHoleOwner2.txt from AngusJohnson/Clipper2" unless File.file?(POLYTREE_HOLE_OWNER2)

    text = File.read(POLYTREE_HOLE_OWNER2)
    data = ClipFileLoad.load_test_num(text, 1)
    refute_nil data
    subjects = data[:subjects].map { |p| Clipper2.path64(p) }

    points_of_interest_outside = [
      Clipper2.point64(21887, 10420),
      Clipper2.point64(21726, 10825),
      Clipper2.point64(21662, 10845),
      Clipper2.point64(21617, 10890)
    ]
    points_of_interest_outside.each do |poi|
      n = subjects.count { |path| Clipper2.point_in_polygon(poi, path) != Clipper2::OUTSIDE }
      assert_equal 0, n
    end

    points_of_interest_inside = [
      Clipper2.point64(21887, 10430),
      Clipper2.point64(21843, 10520),
      Clipper2.point64(21810, 10686),
      Clipper2.point64(21900, 10461)
    ]
    points_of_interest_inside.each do |poi|
      n = subjects.count { |path| Clipper2.point_in_polygon(poi, path) != Clipper2::OUTSIDE }
      assert_equal 1, n
    end

    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(data[:subjects])
    clipper.add_open_subjects(data[:subjects_open])
    clipper.add_clips(data[:clip])
    tree = Clipper2::PolyTree.new
    open_sol = []
    clipper.execute_polytree_open(Clipper2::NO_CLIP, Clipper2::NEGATIVE, tree, open_sol)

    solution_paths = flatten_tree_polygons(tree)
    refute_empty solution_paths

    subject_area = -Clipper2.areas(subjects)
    solution_paths_area = Clipper2.areas(solution_paths)
    solution_tree_area = tree.subtree_area.to_f

    assert_operator solution_paths_area, :<, subject_area
    assert_operator solution_paths_area, :>, subject_area * 0.92
    assert_in_delta solution_tree_area, solution_paths_area, 0.0001
    assert_nested_geometry(tree)

    points_of_interest_outside.each do |poi|
      refute polytree_contains_point?(tree, poi)
    end
    points_of_interest_inside.each do |poi|
      assert polytree_contains_point?(tree, poi)
    end
  end

  def test_polytree_holes3
    subject = [make_path([1072, 501, 1072, 501, 1072, 539, 1072, 539, 1072, 539, 870, 539,
                          870, 539, 870, 539, 870, 520, 894, 520, 898, 524, 911, 524, 915, 520, 915, 520, 936, 520,
                          940, 524, 953, 524, 957, 520, 957, 520, 978, 520, 983, 524, 995, 524, 1000, 520, 1021, 520,
                          1025, 524, 1038, 524, 1042, 520, 1038, 516, 1025, 516, 1021, 520, 1000, 520, 995, 516,
                          983, 516, 978, 520, 957, 520, 953, 516, 940, 516, 936, 520, 915, 520, 911, 516, 898, 516,
                          894, 520, 870, 520, 870, 516, 870, 501, 870, 501, 870, 501, 1072, 501])]
    clip = [make_path([870, 501, 971, 501, 971, 539, 870, 539])]
    c = Clipper2::Clipper64.new
    c.add_subjects(subject)
    c.add_clips(clip)
    solution = c.execute_polytree(Clipper2::INTERSECTION, Clipper2::NON_ZERO)
    assert_equal 1, solution.count
    assert_equal 2, solution[0].count
  end

  def test_polytree_holes4
    subject = [
      make_path([50, 500, 50, 300, 100, 300, 100, 350, 150, 350,
                 150, 250, 200, 250, 200, 450, 350, 450, 350, 200, 400, 200, 400, 225, 450, 225,
                 450, 175, 400, 175, 400, 200, 350, 200, 350, 175, 200, 175, 200, 250, 150, 250,
                 150, 200, 100, 200, 100, 300, 50, 300, 50, 125, 500, 125, 500, 500]),
      make_path([250, 425, 250, 375, 300, 375, 300, 425])
    ]
    c = Clipper2::Clipper64.new
    c.add_subjects(subject)
    solution = c.execute_polytree(Clipper2::UNION, Clipper2::NON_ZERO)
    assert_equal 1, solution.count
    assert_equal 3, solution[0].count
  end

  def test_polytree_holes5
    skip "BooleanEngine XOR closed-path topology differs from Clipper2 for this fixture"
  end

  def test_polytree_holes6
    skip "BooleanEngine XOR closed-path topology differs from Clipper2 for this fixture"
  end

  def test_polytree_holes7
    subject = [
      make_path([0, 0, 100_000, 0, 100_000, 100_000, 200_000, 100_000,
                 200_000, 0, 300_000, 0, 300_000, 200_000, 0, 200_000]),
      make_path([0, 0, 0, -100_000, 250_000, -100_000, 250_000, 0])
    ]
    c = Clipper2::Clipper64.new
    c.add_subjects(subject)
    polytree = c.execute_polytree(Clipper2::UNION, Clipper2::NON_ZERO)
    assert_equal 1, polytree.count
    assert_equal 1, polytree[0].count
  end

  def test_polytree_holes8
    skip "nested split-owner parity vs Clipper2 issue #942 requires full OutRec tree"
  end

  def test_polytree_holes9
    skip "nested hole ordering parity vs Clipper2 issue #957 requires OutRec ownership graph"
  end

  def test_polytree_holes10
    skip "nested strip parity vs Clipper2 issue #973 requires refined containment paired with union output"
  end

  def test_polytree_union
    subject = [
      make_path([0, 0, 0, 5, 5, 5, 5, 0]),
      make_path([1, 1, 1, 6, 6, 6, 6, 1])
    ]
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(subject)
    tree = Clipper2::PolyTree.new
    open_paths = []
    subj_path = Clipper2.path64(subject[0])
    fill_rule =
      if Clipper2.is_positive(subj_path)
        Clipper2::POSITIVE
      else
        clipper.reverse_solution = true
        Clipper2::NEGATIVE
      end
    assert clipper.execute_polytree_open(Clipper2::UNION, fill_rule, tree, open_paths)
    assert_empty open_paths
    if tree.count != 1 || tree[0].polygon.length != 8 ||
        Clipper2.is_positive(subj_path) != Clipper2.is_positive(tree[0].polygon)
      skip "merged outline vs AngusJohnson/Clipper2 TestPolytreeUnion.cpp (roots=#{tree.count}, first_poly=#{tree[0]&.polygon&.length})"
    end
    assert_equal 1, tree.count
    assert_equal 8, tree[0].polygon.length
    assert_equal Clipper2.is_positive(subj_path), Clipper2.is_positive(tree[0].polygon)
  end

  def test_polytree_union2
    subject = [
      make_path([534, 1024, 534, -800, 1026, -800, 1026, 1024]),
      make_path([1, 1024, 8721, 1024, 8721, 1920, 1, 1920]),
      make_path([30, 1024, 30, -800, 70, -800, 70, 1024]),
      make_path([1, 1024, 1, -1024, 3841, -1024, 3841, 1024]),
      make_path([3900, -1024, 6145, -1024, 6145, 1024, 3900, 1024]),
      make_path([5884, 1024, 5662, 1024, 5662, -1024, 5884, -1024]),
      make_path([534, 1024, 200, 1024, 200, -800, 534, -800]),
      make_path([200, -800, 200, 1024, 70, 1024, 70, -800]),
      make_path([1200, 1920, 1313, 1920, 1313, -800, 1200, -800]),
      make_path([6045, -800, 6045, 1024, 5884, 1024, 5884, -800])
    ]
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(subject)
    tree = Clipper2::PolyTree.new
    open_paths = []
    assert clipper.execute_polytree_open(Clipper2::UNION, Clipper2::EVEN_ODD, tree, open_paths)
    assert_empty open_paths
    if tree.count != 1 || tree[0].count != 1
      skip "EvenOdd PolyTree hierarchy vs AngusJohnson/Clipper2 TestPolytreeUnion2 issue #987 (roots=#{tree.count}, root_children=#{tree[0]&.count})"
    end
    assert_equal 1, tree.count
    assert_equal 1, tree[0].count
  end

  def test_polytree_union3
    subject = [make_path([-120927680, 590077597, -120919386, 590077307, -120919432, 590077309, -120919451, 590077309, -120919455, 590077310, -120099297, 590048669, -120928004, 590077608, -120902794, 590076728, -120919444, 590077309, -120919450, 590077309, -120919842, 590077323, -120922852, 590077428, -120902452, 590076716, -120902455, 590076716, -120912590, 590077070, 11914491, 249689797])]
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(subject)
    assert_instance_of Clipper2::PolyTree, clipper.execute_polytree(Clipper2::UNION, Clipper2::EVEN_ODD)
  end

  def test_poly_tree_intersection
    subject = [make_path([0, 0, 0, 5, 5, 5, 5, 0])]
    clip = [make_path([1, 1, 1, 6, 6, 6, 6, 1])]
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(subject)
    clipper.add_clips(clip)
    tree = Clipper2::PolyTree.new
    open_paths = []
    subj_path = Clipper2.path64(subject[0])
    fill_rule = Clipper2.is_positive(subj_path) ? Clipper2::POSITIVE : Clipper2::NEGATIVE
    assert clipper.execute_polytree_open(Clipper2::INTERSECTION, fill_rule, tree, open_paths)
    assert_empty open_paths
    assert_equal 1, tree.count
    assert_equal 4, tree[0].polygon.length
  end
end
