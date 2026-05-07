require_relative "test_helper"

class UpstreamPolytreeTest < Minitest::Test
  include Clipper2TestHelpers

  def test_polytree_holes1
    skip "requires upstream PolytreeHoleOwner.txt fixture conversion"
  end

  def test_polytree_holes2
    skip "requires upstream PolytreeHoleOwner2.txt fixture conversion"
  end

  def test_polytree_holes3
    skip "requires nested PolyTree hole ownership parity"
  end

  def test_polytree_holes4
    skip "requires nested PolyTree hole ownership parity"
  end

  def test_polytree_holes5
    skip "requires nested PolyTree xor ownership parity"
  end

  def test_polytree_holes6
    skip "requires nested PolyTree xor ownership parity"
  end

  def test_polytree_holes7
    skip "requires nested PolyTree union ownership parity"
  end

  def test_polytree_holes8
    skip "requires upstream issue #942 PolyTree ownership parity"
  end

  def test_polytree_holes9
    skip "requires upstream issue #957 PolyTree ownership parity"
  end

  def test_polytree_holes10
    skip "requires upstream issue #973 PolyTree ownership parity"
  end

  def test_polytree_union
    skip "requires exact PolyTree hierarchy parity"
    subject = [
      make_path([0, 0, 0, 5, 5, 5, 5, 0]),
      make_path([1, 1, 1, 6, 6, 6, 6, 1])
    ]
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(subject)
    tree = clipper.execute_polytree(Clipper2::UNION, Clipper2::NEGATIVE)
    assert_equal 1, tree.count
  end

  def test_polytree_union2
    skip "requires exact PolyTree EvenOdd hierarchy parity"
  end

  def test_polytree_union3
    subject = [make_path([-120927680, 590077597, -120919386, 590077307, -120919432, 590077309, -120919451, 590077309, -120919455, 590077310, -120099297, 590048669, -120928004, 590077608, -120902794, 590076728, -120919444, 590077309, -120919450, 590077309, -120919842, 590077323, -120922852, 590077428, -120902452, 590076716, -120902455, 590076716, -120912590, 590077070, 11914491, 249689797])]
    clipper = Clipper2::Clipper64.new
    clipper.add_subjects(subject)
    assert_instance_of Clipper2::PolyTree, clipper.execute_polytree(Clipper2::UNION, Clipper2::EVEN_ODD)
  end

  def test_poly_tree_intersection
    skip "requires exact PolyTree intersection hierarchy parity"
    clipper = Clipper2::Clipper64.new
    clipper.add_subject(make_path([0, 0, 0, 5, 5, 5, 5, 0]))
    clipper.add_clip(make_path([1, 1, 1, 6, 6, 6, 6, 1]))
    tree = clipper.execute_polytree(Clipper2::INTERSECTION, Clipper2::NEGATIVE)
    assert_equal 1, tree.count
    assert_equal 4, tree[0].polygon.length
  end
end
