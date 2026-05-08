require_relative "test_helper"

class DShapeAspireTest < Minitest::Test
  SCALE = 1000
  TOOL_RADIUS_MM = 3.0

  def test_d_shape_offset_matches_aspire_profile_bounds_and_area
    expected = Clipper2.path64(aspire_profile_contour, scale: SCALE)
    source = Clipper2.inflate_paths([expected], -(TOOL_RADIUS_MM * SCALE).round, Clipper2::MITER, Clipper2::POLYGON).first
    generated = Clipper2.inflate_paths([source], (TOOL_RADIUS_MM * SCALE).round, Clipper2::MITER, Clipper2::POLYGON)
    log_lengths = cutting_line_lengths

    assert_equal 125, log_lengths.length
    assert_in_delta 57.035, log_lengths.max, 0.001
    assert_equal 1, generated.length
    assert_equal Clipper2.orientation(expected), Clipper2.orientation(generated.first)
    assert_bbox_in_delta expected, generated.first, 0.001
    assert_in_delta area_mm2(expected), area_mm2(generated.first), 25.0
    assert_operator generated.first.length, :>=, expected.length
  end

  private

  def aspire_profile_contour
    contours = parse_nc_contours(File.join(__dir__, "Profile 1.nc"))
    contours.max_by { |path| polygon_area(path).abs }
  end

  def cutting_line_lengths
    File.read(File.join(__dir__, "D-shape_20260508_110843.txt")).scan(/edge: length_mm=([0-9.]+)/).flatten.map(&:to_f)
  end

  def parse_nc_contours(path)
    contours = []
    current = nil
    x = nil
    y = nil
    cutting = false

    File.readlines(path).each do |line|
      g = line[/\bG([0123])\b/, 1]
      nx = numeric_word(line, "X")
      ny = numeric_word(line, "Y")
      z = numeric_word(line, "Z")

      if z && z < 0 && !cutting
        current = []
        current << [x, y] if x && y
        cutting = true
      elsif z && z > 0 && cutting
        contours << current if current && current.length > 1
        current = nil
        cutting = false
      end

      if g == "0"
        x = nx if nx
        y = ny if ny
        next
      end

      next unless cutting && nx && ny && %w[1 2 3].include?(g)

      if %w[2 3].include?(g)
        append_arc_points(current, x, y, nx, ny, numeric_word(line, "I") || 0.0, numeric_word(line, "J") || 0.0, g)
      else
        current << [nx, ny]
      end

      x = nx
      y = ny
    end

    contours
  end

  def numeric_word(line, word)
    line[/\b#{word}(-?\d+(?:\.\d+)?)/, 1]&.to_f
  end

  def append_arc_points(points, x, y, nx, ny, i, j, g)
    cx = x + i
    cy = y + j
    a0 = Math.atan2(y - cy, x - cx)
    a1 = Math.atan2(ny - cy, nx - cx)
    if g == "3"
      a1 += Math::PI * 2 while a1 <= a0
    else
      a1 -= Math::PI * 2 while a1 >= a0
    end
    sweep = a1 - a0
    radius = Math.hypot(x - cx, y - cy)
    steps = [(sweep.abs * radius / 0.5).ceil, 2].max
    1.upto(steps) do |step|
      angle = a0 + sweep * step / steps
      points << [cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius]
    end
  end

  def polygon_area(path)
    path.each_with_index.sum do |point, index|
      nxt = path[(index + 1) % path.length]
      point[0] * nxt[1] - nxt[0] * point[1]
    end / 2.0
  end

  def area_mm2(path)
    Clipper2.area(path).abs / SCALE / SCALE
  end

  def assert_bbox_in_delta(expected, actual, delta)
    expected_box = bbox_mm(expected)
    actual_box = bbox_mm(actual)
    expected_box.zip(actual_box).each do |expected_value, actual_value|
      assert_in_delta expected_value, actual_value, delta
    end
  end

  def bbox_mm(path)
    [
      path.map(&:x).min / SCALE.to_f,
      path.map(&:y).min / SCALE.to_f,
      path.map(&:x).max / SCALE.to_f,
      path.map(&:y).max / SCALE.to_f
    ]
  end
end
