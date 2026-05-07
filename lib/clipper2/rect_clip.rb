require_relative "engine"

module Clipper2
  module_function

  def rect_clip(rect, paths)
    rectangle = normalize_rect(rect)
    paths64(paths).filter_map do |path|
      clipped = clip_path_to_rect(path, rectangle)
      clipped.length >= 3 ? clipped : nil
    end
  end

  def rect_clip_lines(rect, paths)
    rectangle = normalize_rect(rect)
    paths64(paths).flat_map do |path|
      path.each_cons(2).filter_map do |a, b|
        line = clip_segment_to_rect(a, b, rectangle)
        line if line && line.length == 2 && distance(line[0], line[1]) > EPSILON
      end
    end
  end

  def normalize_rect(rect)
    return rect if rect.is_a?(Rect64)
    if rect.is_a?(RectD)
      Rect64.new(left: rect.left.round, top: rect.top.round, right: rect.right.round, bottom: rect.bottom.round)
    else
      Rect64.new(left: rect[0], top: rect[1], right: rect[2], bottom: rect[3])
    end
  end

  def clip_path_to_rect(path, rect)
    result = path
    result = clip_against_edge(result, ->(point) { point.x >= rect.left }, ->(a, b) { intersect_vertical(a, b, rect.left) })
    result = clip_against_edge(result, ->(point) { point.x <= rect.right }, ->(a, b) { intersect_vertical(a, b, rect.right) })
    result = clip_against_edge(result, ->(point) { point.y >= rect.top }, ->(a, b) { intersect_horizontal(a, b, rect.top) })
    result = clip_against_edge(result, ->(point) { point.y <= rect.bottom }, ->(a, b) { intersect_horizontal(a, b, rect.bottom) })
    clean_path(result)
  end

  def clip_against_edge(path, inside, intersection)
    return [] if path.empty?
    output = []
    prev = path[-1]
    prev_inside = inside.call(prev)
    path.each do |cur|
      cur_inside = inside.call(cur)
      if cur_inside
        output << intersection.call(prev, cur) unless prev_inside
        output << cur
      elsif prev_inside
        output << intersection.call(prev, cur)
      end
      prev = cur
      prev_inside = cur_inside
    end
    output
  end

  def intersect_vertical(a, b, x)
    dx = b.x - a.x
    return Point64.new(x: x, y: a.y, z: a.z) if dx.zero?
    t = (x - a.x).to_f / dx
    Point64.new(x: x, y: (a.y + (b.y - a.y) * t).round, z: a.z)
  end

  def intersect_horizontal(a, b, y)
    dy = b.y - a.y
    return Point64.new(x: a.x, y: y, z: a.z) if dy.zero?
    t = (y - a.y).to_f / dy
    Point64.new(x: (a.x + (b.x - a.x) * t).round, y: y, z: a.z)
  end

  def clip_segment_to_rect(a, b, rect)
    x0 = a.x.to_f
    y0 = a.y.to_f
    x1 = b.x.to_f
    y1 = b.y.to_f
    dx = x1 - x0
    dy = y1 - y0
    t0 = 0.0
    t1 = 1.0
    checks = [
      [-dx, x0 - rect.left],
      [dx, rect.right - x0],
      [-dy, y0 - rect.top],
      [dy, rect.bottom - y0]
    ]
    checks.each do |p, q|
      if p.abs <= EPSILON
        return nil if q < 0
      else
        r = q / p
        if p < 0
          return nil if r > t1
          t0 = [t0, r].max
        else
          return nil if r < t0
          t1 = [t1, r].min
        end
      end
    end
    [
      Point64.new(x: (x0 + t0 * dx).round, y: (y0 + t0 * dy).round, z: a.z),
      Point64.new(x: (x0 + t1 * dx).round, y: (y0 + t1 * dy).round, z: b.z)
    ]
  end
end
