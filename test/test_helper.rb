require "minitest/autorun"
require_relative "../lib/clipper2"

module Clipper2TestHelpers
  def make_path(values)
    values.each_slice(2).map { |x, y| [x, y] }
  end

  def make_pathd(values)
    values.each_slice(2).map { |x, y| [x.to_f, y.to_f] }
  end

  def square(left, top, right, bottom)
    [[left, top], [right, top], [right, bottom], [left, bottom]]
  end

  def path_area(paths)
    paths.sum { |path| Clipper2.area(path) }
  end

  def assert_area_in_delta(expected, paths, delta = 0.001)
    assert_in_delta expected, path_area(paths).abs, delta
  end
end
