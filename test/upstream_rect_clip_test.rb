require_relative "test_helper"

class UpstreamRectClipTest < Minitest::Test
  include Clipper2TestHelpers

  def test_rect_clip
    rect = Clipper2::Rect64.new(left: 100, top: 100, right: 700, bottom: 500)
    clip_area = Clipper2.area(rect.as_path)
    sub = [make_path([100, 100, 700, 100, 700, 500, 100, 500])]
    sol = Clipper2.rect_clip(rect, sub)
    assert_equal path_area(Clipper2.paths64(sub)), path_area(sol)
    sub = [make_path([110, 110, 700, 100, 700, 500, 100, 500])]
    sol = Clipper2.rect_clip(rect, sub)
    assert_equal path_area(Clipper2.paths64(sub)), path_area(sol)
    sub = [make_path([90, 90, 700, 100, 700, 500, 100, 500])]
    sol = Clipper2.rect_clip(rect, sub)
    assert_equal clip_area, path_area(sol)
    sub = [make_path([110, 110, 690, 110, 690, 490, 110, 490])]
    sol = Clipper2.rect_clip(rect, sub)
    assert_equal path_area(Clipper2.paths64(sub)), path_area(sol)
    rect = Clipper2::Rect64.new(left: 390, top: 290, right: 410, bottom: 310)
    assert_empty Clipper2.rect_clip(rect, [make_path([410, 290, 500, 290, 500, 310, 410, 310])])
    assert_empty Clipper2.rect_clip(rect, [make_path([430, 290, 470, 330, 390, 330])])
    assert_empty Clipper2.rect_clip(rect, [make_path([450, 290, 480, 330, 450, 330])])
    sub = [make_path([208, 66, 366, 112, 402, 303, 234, 332, 233, 262, 243, 140, 215, 126, 40, 172])]
    rect = Clipper2::Rect64.new(left: 237, top: 164, right: 322, bottom: 248)
    bounds = Clipper2.bounds(Clipper2.rect_clip(rect, sub))
    assert_equal rect.width, bounds.width
    assert_equal rect.height, bounds.height
  end

  def test_rect_clip2
    rect = Clipper2::Rect64.new(left: 54690, top: 0, right: 65628, bottom: 6000)
    subject = [[[700000, 6000], [0, 6000], [0, 5925], [700000, 5925]]]
    solution = Clipper2.rect_clip(rect, subject)
    assert_equal 1, solution.length
    assert_equal 4, solution[0].length
  end

  def test_rect_clip3
    rect = Clipper2::Rect64.new(left: -1_800_000_000, top: -137_573_171, right: -1_741_475_021, bottom: 3_355_443)
    subject = [make_path([-1_800_000_000, 10_005_000, -1_800_000_000, -5000, -1_789_994_999, -5000, -1_789_994_999, 10_005_000])]
    assert_equal 1, Clipper2.rect_clip(rect, subject).length
  end

  def test_rect_clip_orientation
    rect = Clipper2::Rect64.new(left: 1222, top: 1323, right: 3247, bottom: 3348)
    subject = make_path([375, 1680, 1915, 4716, 5943, 586, 3987, 152])
    solution = Clipper2.rect_clip(rect, [subject])
    assert_equal 1, solution.length
    assert_equal Clipper2.orientation(Clipper2.path64(subject)), Clipper2.orientation(solution.first)
  end
end
