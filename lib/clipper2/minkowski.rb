require_relative "engine"

module Clipper2
  module_function

  def minkowski_sum(pattern, path, path_is_closed = true)
    pattern = path64(pattern)
    path = path64(path)
    quads = minkowski_quads(pattern, path, false, path_is_closed)
    union(quads)
  end

  def minkowski_diff(pattern, path, path_is_closed = true)
    pattern = path64(pattern)
    path = path64(path)
    quads = minkowski_quads(pattern, path, true, path_is_closed)
    union(quads)
  end

  def minkowski_quads(pattern, path, difference, path_is_closed)
    return [] if pattern.empty? || path.empty?
    translated = path.map do |point|
      pattern.map do |pat|
        if difference
          Point64.new(x: point.x - pat.x, y: point.y - pat.y, z: point.z)
        else
          Point64.new(x: point.x + pat.x, y: point.y + pat.y, z: point.z)
        end
      end
    end
    last = path_is_closed ? path.length - 1 : path.length - 2
    quads = []
    (0..last).each do |i|
      ni = (i + 1) % path.length
      pattern.each_index do |j|
        nj = (j + 1) % pattern.length
        quad = [translated[i][j], translated[ni][j], translated[ni][nj], translated[i][nj]]
        quad.reverse! if area(quad) < 0
        quads << quad
      end
    end
    quads
  end
end
