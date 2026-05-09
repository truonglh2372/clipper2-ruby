require_relative "core"
require_relative "triangulation_delaunay"

module Clipper2
  TRIANGULATE_SUCCESS = :success
  TRIANGULATE_FAIL = :fail
  TRIANGULATE_NO_POLYGONS = :no_polygons
  TRIANGULATE_PATHS_INTERSECT = :paths_intersect

  Triangle = Struct.new(:a, :b, :c, keyword_init: true) do
    def to_a
      [a, b, c]
    end
  end

  TriangulateResult = Struct.new(:triangles, keyword_init: true) do
    def initialize(triangles: [])
      super(triangles: triangles)
    end

    def to_a
      triangles.map(&:to_a)
    end
  end

  module_function

  def triangulate_paths64(pp, use_delaunay: true)
    paths = paths64(pp)
    return [TRIANGULATE_NO_POLYGONS, []] if paths.empty? || paths.sum(&:length).zero?

    tri_box = [:pending]
    sol = TriangulationDelaunay::Engine.new(use_delaunay).execute(paths, tri_box)
    case tri_box[0]
    when :success
      [TRIANGULATE_SUCCESS, sol]
    when :no_polygons
      [TRIANGULATE_NO_POLYGONS, []]
    when :paths_intersect
      [TRIANGULATE_PATHS_INTERSECT, []]
    else
      [TRIANGULATE_FAIL, []]
    end
  end

  def triangulate_paths_d(pp, dec_places:, use_delaunay: true)
    scale =
      if dec_places <= 0
        1.0
      elsif dec_places > 8
        10.0**8
      else
        10.0**dec_places
      end
    pp64 = paths64(pp, scale: scale)
    result, sol64 = triangulate_paths64(pp64, use_delaunay: use_delaunay)
    return [result, []] if result != TRIANGULATE_SUCCESS
    [TRIANGULATE_SUCCESS, unscale_paths(sol64, scale)]
  end

  def triangulate(paths)
    status, sol = triangulate_paths64(paths, use_delaunay: true)
    triangles =
      if status == TRIANGULATE_SUCCESS
        sol.map { |t| Triangle.new(a: t[0], b: t[1], c: t[2]) }
      else
        []
      end
    TriangulateResult.new(triangles: triangles)
  end

  def triangulate_path(path)
    p64 = paths64([path]).first
    return [] if !p64 || p64.length < 3
    status, sol = triangulate_paths64([p64], use_delaunay: true)
    return nil if status != TRIANGULATE_SUCCESS
    sol.map { |t| Triangle.new(a: t[0], b: t[1], c: t[2]) }
  end
end
