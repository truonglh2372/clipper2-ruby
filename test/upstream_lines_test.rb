require_relative "test_helper"
require_relative "clip_file_load"

class UpstreamLinesTest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/Lines.txt", __dir__)

  def test_multiple_lines
    text = File.read(FIXTURE)
    test_number = 1
    loop do
      data = ClipFileLoad.load_test_num(text, test_number)
      break unless data

      c = Clipper2::Clipper64.new
      data[:subjects].each { |path| c.add_subject(path) }
      data[:subjects_open].each { |path| c.add_open_subject(path) }
      data[:clip].each { |path| c.add_clip(path) }

      sol = []
      sol_open = []
      assert c.execute_closed_open(data[:clip_type], data[:fill_rule], sol, sol_open)

      if test_number == 1
        assert_equal 1, sol.size
        assert sol[0]
        assert_equal 6, sol[0].size
        assert Clipper2.is_positive(sol[0])
        assert_in_delta data[:sol_area].abs, Clipper2.area(sol[0]).abs, 0.001
        assert_equal 1, sol_open.size
        assert sol_open[0]
        assert_equal 2, sol_open[0].size
        assert_equal 6, sol_open[0][0].y
      else
        count2 = sol.size + sol_open.size
        count_diff = (count2 - data[:sol_count]).abs
        relative = data[:sol_count].nonzero? ? count_diff.to_f / data[:sol_count] : 0.0
        assert_operator count_diff, :<=, 8
        assert_operator relative, :<=, 0.1
      end

      test_number += 1
    end

    assert_operator test_number, :>=, 17
  end
end
