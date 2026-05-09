require_relative "test_helper"
require_relative "clip_file_load"
require "json"

class UpstreamOffsetsTest < Minitest::Test
  include Clipper2TestHelpers

  OFFSETS_TXT = File.expand_path("fixtures/Offsets.txt", __dir__)

  def test_offsets
    text = File.read(OFFSETS_TXT)
    (1..2).each do |tn|
      data = ClipFileLoad.load_test_num(text, tn)
      refute_nil data
      co = Clipper2::ClipperOffset.new
      co.add_paths(data[:subjects], Clipper2::ROUND, Clipper2::POLYGON)
      outputs = co.execute(1)
      outer_pos = Clipper2.areas(outputs) > 0
      pos_cnt = outputs.count { |p| Clipper2.is_positive(p) }
      neg_cnt = outputs.size - pos_cnt
      if outer_pos
        assert_equal 1, pos_cnt
      else
        assert_equal 1, neg_cnt
      end
    end
  end

  def test_offsets2
    scale = 10.0
    delta = 10 * scale
    arc_tol = 0.25 * scale
    subject = [make_path([50, 50, 100, 50, 100, 150, 50, 150, 0, 100])]
    ec = [0]
    subject64 = Clipper2.scale_paths([Clipper2.path64(subject[0])], scale, scale, ec)
    c = Clipper2::ClipperOffset.new(2, arc_tol)
    c.add_paths(subject64, Clipper2::ROUND, Clipper2::POLYGON)
    solution = c.execute(delta)
    assert_equal 1, solution.length
    min_dist = delta * 2
    max_dist = 0.0
    subj0 = subject64[0]
    sol0 = solution[0]
    prev_pt = sol0[-1]
    sol0.each do |pt|
      subj0.each do |subj_pt|
        mp_x = (prev_pt.x + pt.x) / 2
        mp_y = (prev_pt.y + pt.y) / 2
        mp = Clipper2.point64(mp_x, mp_y)
        d = Clipper2.distance(mp, subj_pt)
        next unless d < delta * 2

        min_dist = d if d < min_dist
        max_dist = d if d > max_dist
      end
      prev_pt = pt
    end
    assert_operator min_dist + 1, :>=, delta - arc_tol
    assert_operator sol0.length, :<=, 21
  end

  def test_offsets3
    paths = JSON.parse(File.read(File.expand_path("fixtures/testoffsets3_paths.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    solution = Clipper2.inflate_paths(paths, -209_715, Clipper2::MITER, Clipper2::POLYGON)
    assert_operator solution[0].length - paths[0].length, :<=, 1
  end

  def test_offsets4
    paths = [[[0, 0], [20_000, 200], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::SQUARE, Clipper2::POLYGON)
    assert_operator (solution[0].length - 5).abs, :<=, 1
    paths = [[[0, 0], [20_000, 400], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::SQUARE, Clipper2::POLYGON)
    assert_operator (solution[0].length - 5).abs, :<=, 1
    paths = [[[0, 0], [20_000, 400], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::ROUND, Clipper2::POLYGON, 2, 100)
    assert_operator solution[0].length, :>, 5
    paths = [[[0, 0], [20_000, 1500], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::ROUND, Clipper2::POLYGON, 2, 100)
    assert_operator solution[0].length, :>, 5
  end

  def test_offsets5
    paths = JSON.parse(File.read(File.expand_path("fixtures/offsets5_paths.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    solution = Clipper2.inflate_paths(paths, -10_000, Clipper2::ROUND, Clipper2::POLYGON)
    assert_equal 2, solution.size
  end

  def test_offsets6
    paths = JSON.parse(File.read(File.expand_path("fixtures/testoffsets6_paths.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    solution = Clipper2.inflate_paths(paths, -50, Clipper2::ROUND, Clipper2::POLYGON)
    assert_equal 2, solution.size
    neg = solution.select { |p| Clipper2.area(p) < 0 }.min_by { |p| Clipper2.area(p) }
    refute_nil neg
    assert_operator Clipper2.area(neg), :<, -47_500
  end

  def test_offsets7
    subject = [make_path([0, 0, 100, 0, 100, 100, 0, 100])]
    solution = Clipper2.inflate_paths(subject, -50, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
    subject.push(make_path([40, 60, 60, 60, 60, 40, 40, 40]))
    solution = Clipper2.inflate_paths(subject, 10, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    subject[0].reverse!
    subject[1].reverse!
    solution = Clipper2.inflate_paths(subject, 10, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    subject.pop
    solution = Clipper2.inflate_paths(subject, -50, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets8
    paths = JSON.parse(File.read(File.expand_path("fixtures/offsets8_subject.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    offset = -50_329_979.277800001
    arc_tol = 5000
    solution = Clipper2.inflate_paths(paths, offset, Clipper2::ROUND, Clipper2::POLYGON, 2, arc_tol)
    refute_empty solution
    smallest_dist, largest_dist = offset_quality_sample_min_max(paths[0], solution[0], offset)
    off = offset.abs
    assert_operator smallest_dist, :>, arc_tol
    assert_operator largest_dist - off, :<=, off * 0.1 + arc_tol
  end

  def test_offsets9
    subject = [make_path([100, 100, 200, 100, 200, 400, 100, 400])]
    solution = Clipper2.inflate_paths(subject, 50, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    assert Clipper2.is_positive(solution[0])
    subject[0].reverse!
    solution = Clipper2.inflate_paths(subject, 50, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    refute Clipper2.is_positive(solution[0])
    co = Clipper2::ClipperOffset.new(2, 0, false, true)
    co.add_paths(subject, Clipper2::MITER, Clipper2::POLYGON)
    sol = []
    co.execute(50, sol)
    solution = sol
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    assert Clipper2.is_positive(solution[0])
    subject.push(make_path([130, 130, 170, 130, 170, 370, 130, 370]))
    solution = Clipper2.inflate_paths(subject, 30, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    refute Clipper2.is_positive(solution[0])
    co.clear
    co.add_paths(subject, Clipper2::MITER, Clipper2::POLYGON)
    co.execute(30, sol)
    solution = sol
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    assert Clipper2.is_positive(solution[0])
    solution = Clipper2.inflate_paths(subject, -15, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets10
    paths = JSON.parse(File.read(File.expand_path("fixtures/offsets10_subjects.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    offseter = Clipper2::ClipperOffset.new(2, 104_857.61318750000)
    offseter.add_paths(paths, Clipper2::ROUND, Clipper2::POLYGON)
    solution = offseter.execute(-2_212_495.6382562499)
    assert_equal 2, solution.size
  end

  def test_offsets11
    subject = [make_path([-1, -1, -1, 11, 11, 11, 11, -1])]
    solution = Clipper2.inflate_paths(subject, -50, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets12
    subject = [[[667_680_768, -36_382_704], [737_202_688, -87_034_880], [742_581_888, -86_055_680], [747_603_968, -84_684_800]]]
    solution = Clipper2.inflate_paths(subject, -249_561_088, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets13
    subject1 = [[[0, 0], [0, 10], [10, 0]]]
    solution1 = Clipper2.inflate_paths(subject1, 2, Clipper2::MITER, Clipper2::POLYGON)
    area1 = Clipper2.area(solution1[0]).abs
    assert_in_delta 122, area1, 8
    subject2 = [[[0, 0], [0, 10], [10, 0]], [[0, 20]]]
    solution2 = Clipper2.inflate_paths(subject2, 2, Clipper2::MITER, Clipper2::POLYGON)
    area2 = Clipper2.area(solution2[0]).abs
    assert_in_delta area1, area2, 1e-6
  end

  private

  def offset_quality_sample_min_max(subject_path, solution_path, delta)
    sub_vertex_count = 4
    sub_vertex_frac = 1.0 / sub_vertex_count
    desired_sqr = delta * delta
    smallest_sqr = desired_sqr
    largest_sqr = desired_sqr
    sol_prev = solution_path[-1]
    solution_path.each do |sol_pt0|
      sub_vertex_count.times do |i|
        sol_pt_x = sol_prev.x.to_f + (sol_pt0.x.to_f - sol_prev.x.to_f) * sub_vertex_frac * i
        sol_pt_y = sol_prev.y.to_f + (sol_pt0.y.to_f - sol_prev.y.to_f) * sub_vertex_frac * i
        sol_pt = Clipper2.pointd(sol_pt_x, sol_pt_y)
        closest_dist_sqr = Float::INFINITY
        sub_prev = subject_path[-1]
        subject_path.each do |sub_pt|
          closest = Clipper2.get_closest_point_on_segment(sol_pt, sub_prev, sub_pt)
          d = Clipper2.distance_sq(closest, sol_pt)
          closest_dist_sqr = d if d < closest_dist_sqr
          sub_prev = sub_pt
        end
        smallest_sqr = closest_dist_sqr if closest_dist_sqr < smallest_sqr
        largest_sqr = closest_dist_sqr if closest_dist_sqr > largest_sqr
      end
      sol_prev = sol_pt0
    end
    [Math.sqrt(smallest_sqr), Math.sqrt(largest_sqr)]
  end
end
