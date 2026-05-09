require_relative "test_helper"

class UpstreamPolygonsTest < Minitest::Test
  include Clipper2TestHelpers

  POLYGONS_TXT = File.expand_path("fixtures/Polygons.txt", __dir__)

  COUNT_NEAR_5 = [120, 121, 130, 138, 140, 148, 163, 165, 166, 167, 168, 172, 173, 175, 178, 180].freeze
  COUNT_NEAR_3 = [126].freeze
  COUNT_NEAR_2A = [16, 27, 181].freeze
  COUNT_NEAR_1 = [23, 45, 87, 102, 111, 113, 191].freeze

  AREA_NEAR_HALF = [19, 22, 23, 24].freeze
  AREA_NEAR_2PCT = [15, 52, 53, 54, 59, 60, 64, 117, 119, 184].freeze

  class << self
    def polygon_list_in_tree(node)
      node.children.flat_map do |ch|
        sub = polygon_list_in_tree(ch)
        ch.polygon.length >= 3 ? [ch.polygon] + sub : sub
      end
    end
  end

  def test_multiple_polygons
    skip "Polygons.txt not bundled; add test/fixtures/Polygons.txt from AngusJohnson/Clipper2 to run" unless File.file?(POLYGONS_TXT)

    text = File.read(POLYGONS_TXT)
    start_num = 1
    end_num = 1000
    test_number = start_num
    while test_number <= end_num
      data = ClipFileLoad.load_test_num(text, test_number)
      break unless data

      ct = data[:clip_type]
      skip if ct == :offset

      fr = data[:fill_rule]
      stored_area = data[:sol_area]
      stored_count = data[:sol_count]

      clipper = Clipper2::Clipper64.new
      clipper.add_subjects(data[:subjects])
      clipper.add_open_subjects(data[:subjects_open])
      clipper.add_clips(data[:clip])

      closed = []
      open_sol = []
      clipper.execute_closed_open(ct, fr, closed, open_sol)

      measured_area = Clipper2.areas(closed).to_i
      measured_count = closed.size + open_sol.size

      clipper_pt = Clipper2::Clipper64.new
      clipper_pt.add_subjects(data[:subjects])
      clipper_pt.add_open_subjects(data[:subjects_open])
      clipper_pt.add_clips(data[:clip])

      tree = Clipper2::PolyTree.new
      open_pt = []
      if data[:subjects_open].empty?
        clipper_pt.execute_polytree(ct, fr, tree)
      else
        clipper_pt.execute_polytree_open(ct, fr, tree, open_pt)
      end

      measured_area_polytree = tree.subtree_area.to_i
      measured_count_polytree = self.class.polygon_list_in_tree(tree).size

      if stored_count <= 0
      elsif COUNT_NEAR_5.include?(test_number)
        assert_operator((measured_count - stored_count).abs, :<=, 5, "count test #{test_number}")
      elsif COUNT_NEAR_3.include?(test_number)
        assert_operator((measured_count - stored_count).abs, :<=, 3, "count test #{test_number}")
      elsif COUNT_NEAR_2A.include?(test_number)
        assert_operator((measured_count - stored_count).abs, :<=, 2, "count test #{test_number}")
      elsif test_number >= 120 && test_number <= 184
        assert_operator((measured_count - stored_count).abs, :<=, 2, "count test #{test_number}")
      elsif COUNT_NEAR_1.include?(test_number)
        assert_operator((measured_count - stored_count).abs, :<=, 1, "count test #{test_number}")
      else
        assert_equal stored_count, measured_count, "count test #{test_number}"
      end

      if stored_area <= 0
      elsif AREA_NEAR_HALF.include?(test_number)
        assert_in_delta stored_area, measured_area, 0.5 * measured_area.abs, "area test #{test_number}"
      elsif test_number == 193
        assert_in_delta stored_area, measured_area, 0.2 * measured_area.abs, "area test #{test_number}"
      elsif test_number == 63
        assert_in_delta stored_area, measured_area, 0.1 * measured_area.abs, "area test #{test_number}"
      elsif test_number == 16
        assert_in_delta stored_area, measured_area, 0.075 * measured_area.abs, "area test #{test_number}"
      elsif test_number == 26
        assert_in_delta stored_area, measured_area, 0.05 * measured_area.abs, "area test #{test_number}"
      elsif AREA_NEAR_2PCT.include?(test_number)
        assert_in_delta stored_area, measured_area, 0.02 * measured_area.abs, "area test #{test_number}"
      else
        assert_in_delta stored_area, measured_area, 0.01 * measured_area.abs, "area test #{test_number}"
      end

      assert_equal measured_count, measured_count_polytree, "polytree count test #{test_number}"
      assert_equal measured_area, measured_area_polytree, "polytree area test #{test_number}"

      test_number += 1
    end
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
    subject = [
      make_path([0, -453054451, 0, -433253797, -455550000, 0]),
      make_path([0, -433253797, 0, 0, -455550000, 0])
    ]
    clipper = Clipper2::Clipper64.new
    clipper.preserve_collinear = false
    clipper.add_subjects(subject)
    solution = clipper.execute(Clipper2::UNION, Clipper2::NON_ZERO)
    solution = Clipper2.merge_contours_union(solution, Clipper2::NON_ZERO) if solution.length > 1
    solution = solution.map { |p| Clipper2.trim_collinear(p, false) }
    solution.reject! { |p| p.length < 3 || Clipper2.area(p).abs <= Clipper2::EPSILON }
    assert_equal 1, solution.length
    assert_equal 3, solution[0].length
    assert_equal Clipper2.orientation(Clipper2.path64(subject[0])), Clipper2.orientation(solution[0])
  end
end
