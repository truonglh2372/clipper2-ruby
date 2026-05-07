# Clipper2 Ruby

A pure Ruby port of the core Clipper2 polygon API.

This gem provides integer and floating-point path types, geometry helpers, boolean polygon operations, offsets, rectangle clipping, Minkowski operations, and triangulation under the `Clipper2` namespace.

The implementation is pure Ruby and does not compile or link the upstream C++ library.

## Installation

Add the gem to your application:

```ruby
gem "clipper2-ruby"
```

Or use it from this repository:

```ruby
$ bundle install
$ ruby -Ilib -e "require 'clipper2'; p Clipper2::VERSION"
```

## Basic Usage

```ruby
require "clipper2"

subject = [
  [[0, 0], [10, 0], [10, 10], [0, 10]]
]

clip = [
  [[5, 5], [15, 5], [15, 15], [5, 15]]
]

solution = Clipper2.intersect(subject, clip)

solution.map { |path| path.map(&:to_a) }
# => [[[5, 5], [10, 5], [10, 10], [5, 10]]]
```

Input paths may be arrays, hashes, `Clipper2::Point64`, or `Clipper2::PointD` objects.

```ruby
Clipper2.point64(10, 20)
Clipper2.point64([10, 20])
Clipper2.point64({ x: 10, y: 20 })

Clipper2.pointd(10.5, 20.25)
```

## Coordinate Types

### `Clipper2::Point64`

Integer point type.

```ruby
pt = Clipper2::Point64.new(x: 10, y: 20)
pt.x
pt.y
pt.to_a
# => [10, 20]
```

### `Clipper2::PointD`

Floating-point point type.

```ruby
pt = Clipper2::PointD.new(x: 10.5, y: 20.25)
pt.to_a
# => [10.5, 20.25]
```

### `Clipper2::Rect64`

Integer rectangle type.

```ruby
rect = Clipper2::Rect64.new(left: 0, top: 0, right: 100, bottom: 50)

rect.width
# => 100

rect.height
# => 50

rect.contains_point?(Clipper2.point64(10, 10))
# => true

rect.as_path.map(&:to_a)
# => [[0, 0], [100, 0], [100, 50], [0, 50]]
```

### `Clipper2::RectD`

Floating-point rectangle type.

```ruby
rect = Clipper2::RectD.new(left: 0.0, top: 0.0, right: 10.5, bottom: 20.25)
rect.width
rect.height
```

### `Clipper2::PolyPath` and `Clipper2::PolyTree`

Simple tree containers for polygon results.

```ruby
tree = Clipper2::PolyTree.new
tree.add_child(Clipper2.path64([[0, 0], [10, 0], [10, 10], [0, 10]]))

tree.count
# => 1

tree[0].polygon.map(&:to_a)
```

## Constants

### Clip Types

```ruby
Clipper2::INTERSECTION
Clipper2::UNION
Clipper2::DIFFERENCE
Clipper2::XOR
```

### Fill Rules

```ruby
Clipper2::EVEN_ODD
Clipper2::NON_ZERO
Clipper2::POSITIVE
Clipper2::NEGATIVE
```

### Join Types

```ruby
Clipper2::MITER
Clipper2::ROUND
Clipper2::SQUARE
Clipper2::BEVEL
```

### End Types

```ruby
Clipper2::POLYGON
Clipper2::JOINED
Clipper2::BUTT
Clipper2::SQUARE_END
Clipper2::ROUND_END
```

### Point-In-Polygon Results

```ruby
Clipper2::INSIDE
Clipper2::OUTSIDE
Clipper2::ON
```

## Core Geometry Functions

### `Clipper2.point64(x, y = nil, z = nil)`

Creates a `Point64`.

```ruby
Clipper2.point64(10, 20).to_a
# => [10, 20]

Clipper2.point64([10, 20]).to_a
# => [10, 20]
```

### `Clipper2.pointd(x, y = nil, z = nil)`

Creates a `PointD`.

```ruby
Clipper2.pointd(10.5, 20.25).to_a
# => [10.5, 20.25]
```

### `Clipper2.to_point64(value, scale: 1)`

Converts an array, hash, `PointD`, or `Point64` into a `Point64`.

```ruby
Clipper2.to_point64([1.25, 2.5], scale: 10).to_a
# => [13, 25]
```

### `Clipper2.to_pointd(value, scale: 1.0)`

Converts an array, hash, `Point64`, or `PointD` into a `PointD`.

```ruby
Clipper2.to_pointd(Clipper2.point64(125, 250), scale: 100).to_a
# => [1.25, 2.5]
```

### `Clipper2.path64(path, scale: 1)`

Converts a path into an array of `Point64` objects and removes duplicate closing points.

```ruby
path = Clipper2.path64([[0, 0], [10, 0], [10, 10], [0, 0]])
path.map(&:to_a)
# => [[0, 0], [10, 0], [10, 10]]
```

### `Clipper2.paths64(paths, scale: 1)`

Converts multiple paths into `Point64` paths.

```ruby
Clipper2.paths64([
  [[0, 0], [10, 0], [10, 10]],
  [[20, 20], [30, 20], [30, 30]]
])
```

### `Clipper2.pathd(path, scale: 1.0)`

Converts a path into an array of `PointD` objects.

```ruby
Clipper2.pathd([[0, 0], [1.5, 0], [1.5, 1.5]])
```

### `Clipper2.pathds(paths, scale: 1.0)`

Converts multiple paths into `PointD` paths.

```ruby
Clipper2.pathds([
  [[0, 0], [1, 0], [1, 1]]
])
```

### `Clipper2.scale_path(path, scale)`

Scales a `PointD` path into integer world coordinates.

```ruby
path = Clipper2.pathd([[0.1, 0.2], [1.5, 2.5]])
Clipper2.scale_path(path, 100).map(&:to_a)
# => [[10, 20], [150, 250]]
```

### `Clipper2.scale_paths(paths, scale)`

Scales multiple paths.

```ruby
Clipper2.scale_paths([Clipper2.pathd([[0.1, 0.2], [1.5, 2.5]])], 100)
```

### `Clipper2.unscale_path(path, scale)`

Converts integer coordinates back to floating-point world coordinates.

```ruby
path = Clipper2.path64([[10, 20], [150, 250]])
Clipper2.unscale_path(path, 100).map(&:to_a)
# => [[0.1, 0.2], [1.5, 2.5]]
```

### `Clipper2.unscale_paths(paths, scale)`

Unscales multiple paths.

```ruby
Clipper2.unscale_paths([Clipper2.path64([[10, 20], [150, 250]])], 100)
```

### `Clipper2.clean_path(path)`

Removes consecutive duplicate points and a duplicate closing point.

```ruby
path = Clipper2.path64([[0, 0], [0, 0], [10, 0], [0, 0]])
Clipper2.clean_path(path).map(&:to_a)
# => [[0, 0], [10, 0]]
```

### `Clipper2.check_range!(paths)`

Raises `Clipper2::RangeError` if any point exceeds `Clipper2::MAX_COORD`.

```ruby
Clipper2.check_range!([Clipper2.path64([[0, 0], [10, 10]])])
# => nil
```

### `Clipper2.cross(a, b, c)`

Returns the 2D cross product for vectors `a->b` and `a->c`.

```ruby
a = Clipper2.point64(0, 0)
b = Clipper2.point64(10, 0)
c = Clipper2.point64(10, 10)

Clipper2.cross(a, b, c)
# => 100
```

### `Clipper2.dot(a, b, c)`

Returns the dot product for vectors `a->b` and `a->c`.

```ruby
Clipper2.dot(a, b, c)
```

### `Clipper2.distance(a, b)`

Returns the Euclidean distance between two points in world coordinates.

```ruby
Clipper2.distance(Clipper2.point64(0, 0), Clipper2.point64(3, 4))
# => 5.0
```

### `Clipper2.distance_sq(a, b)`

Returns squared distance.

```ruby
Clipper2.distance_sq(Clipper2.point64(0, 0), Clipper2.point64(3, 4))
# => 25
```

### `Clipper2.length(path)`

Returns the open path length by summing segment distances.

```ruby
path = Clipper2.path64([[0, 0], [3, 4], [6, 8]])
Clipper2.length(path)
# => 10.0
```

### `Clipper2.area(path)`

Returns signed polygon area.

```ruby
path = Clipper2.path64([[0, 0], [10, 0], [10, 10], [0, 10]])
Clipper2.area(path)
# => 100.0
```

### `Clipper2.areas(paths)`

Returns the sum of signed areas.

```ruby
Clipper2.areas([
  Clipper2.path64([[0, 0], [10, 0], [10, 10], [0, 10]])
])
# => 100.0
```

### `Clipper2.orientation(path)`

Returns `true` when signed area is positive or zero.

```ruby
Clipper2.orientation(path)
# => true
```

### `Clipper2.reverse_path(path)`

Returns the path in reverse order.

```ruby
Clipper2.reverse_path(path)
```

### `Clipper2.reverse_paths(paths)`

Returns all paths in reverse order.

```ruby
Clipper2.reverse_paths([path])
```

### `Clipper2.bounds(paths)`

Returns the bounding rectangle for a set of paths.

```ruby
rect = Clipper2.bounds([path])
rect.left
rect.top
rect.right
rect.bottom
```

### `Clipper2.on_segment?(a, b, p)`

Returns `true` when point `p` lies on segment `a-b`.

```ruby
Clipper2.on_segment?(Clipper2.point64(0, 0), Clipper2.point64(10, 0), Clipper2.point64(5, 0))
# => true
```

### `Clipper2.point_in_polygon(point, path)`

Returns `Clipper2::INSIDE`, `Clipper2::OUTSIDE`, or `Clipper2::ON`.

```ruby
polygon = Clipper2.path64([[0, 0], [10, 0], [10, 10], [0, 10]])

Clipper2.point_in_polygon(Clipper2.point64(5, 5), polygon)
# => :inside
```

### `Clipper2.point_in_paths(point, paths, fill_rule = Clipper2::NON_ZERO)`

Tests a point against multiple paths using a fill rule.

```ruby
Clipper2.point_in_paths(Clipper2.point64(5, 5), [polygon], Clipper2::NON_ZERO)
# => true
```

### `Clipper2.winding_number(point, paths)`

Returns the winding number of a point against a set of paths.

```ruby
Clipper2.winding_number(Clipper2.point64(5, 5), [polygon])
```

### `Clipper2.is_collinear?(a, b, c)`

Returns `true` when three points are collinear.

```ruby
Clipper2.is_collinear?(
  Clipper2.point64(0, 0),
  Clipper2.point64(5, 5),
  Clipper2.point64(10, 10)
)
# => true
```

### `Clipper2.trim_collinear(path, preserve_collinear = false)`

Removes collinear vertices from a path.

```ruby
path = Clipper2.path64([[0, 0], [5, 0], [10, 0], [10, 10], [0, 10]])
Clipper2.trim_collinear(path).map(&:to_a)
# => [[10, 0], [10, 10], [0, 10], [0, 0]]
```

### `Clipper2.perpendicular_distance(point, line_start, line_end)`

Returns the perpendicular distance from a point to a line.

```ruby
Clipper2.perpendicular_distance(
  Clipper2.point64(5, 5),
  Clipper2.point64(0, 0),
  Clipper2.point64(10, 0)
)
# => 5.0
```

### `Clipper2.ramer_douglas_peucker(path, epsilon)`

Simplifies a path using the Ramer-Douglas-Peucker algorithm.

```ruby
path = Clipper2.path64([[0, 0], [1, 1], [2, 2], [10, 10]])
Clipper2.ramer_douglas_peucker(path, 1.0)
```

### `Clipper2.simplify_path(path, epsilon = Math.sqrt(2.0))`

Runs Ramer-Douglas-Peucker and collinear trimming.

```ruby
Clipper2.simplify_path(path)
```

### `Clipper2.simplify_paths(paths, epsilon = Math.sqrt(2.0))`

Simplifies multiple paths and drops paths with fewer than three vertices.

```ruby
Clipper2.simplify_paths([path])
```

### `Clipper2.invalid_rect64`

Returns an invalid `Rect64`, useful as a starting value for rectangle unions.

```ruby
rect = Clipper2.invalid_rect64
rect.invalid?
# => true
```

### `Clipper2.multiply_uint64(a, b)`

Multiplies two unsigned 64-bit-style integers and returns high and low 64-bit parts.

```ruby
parts = Clipper2.multiply_uint64(0xffff_ffff_ffff_ffff, 2)
parts.hi
parts.lo
```

## Boolean Operations

Boolean operations accept arrays of closed paths and return arrays of `Point64` paths unless using `boolean_op_d`.

### `Clipper2.boolean_op(clip_type, subjects, clips, fill_rule = Clipper2::NON_ZERO)`

Runs a boolean operation.

```ruby
solution = Clipper2.boolean_op(
  Clipper2::INTERSECTION,
  [[[0, 0], [10, 0], [10, 10], [0, 10]]],
  [[[5, 5], [15, 5], [15, 15], [5, 15]]],
  Clipper2::NON_ZERO
)
```

### `Clipper2.intersect(subjects, clips, fill_rule = Clipper2::NON_ZERO)`

Returns the intersection of subjects and clips.

```ruby
Clipper2.intersect(subject, clip)
```

### `Clipper2.union(subjects, clips = [], fill_rule = Clipper2::NON_ZERO)`

Returns the union of subject and clip paths.

```ruby
Clipper2.union(subject)
Clipper2.union(subject, clip)
```

### `Clipper2.difference(subjects, clips, fill_rule = Clipper2::NON_ZERO)`

Subtracts clips from subjects.

```ruby
Clipper2.difference(subject, clip)
```

### `Clipper2.xor(subjects, clips, fill_rule = Clipper2::NON_ZERO)`

Returns the exclusive-or result.

```ruby
Clipper2.xor(subject, clip)
```

### `Clipper2.boolean_op_d(clip_type, subjects, clips, fill_rule = Clipper2::NON_ZERO, precision = 2)`

Runs a boolean operation with floating-point input. Coordinates are scaled internally by `10 ** precision` and unscaled after execution.

```ruby
solution = Clipper2.boolean_op_d(
  Clipper2::INTERSECTION,
  [[[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]],
  [[[0.5, 0.5], [1.5, 0.5], [1.5, 1.5], [0.5, 1.5]]],
  Clipper2::NON_ZERO,
  3
)
```

## Clipper Classes

### `Clipper2::Clipper64`

Stateful integer clipping engine.

```ruby
clipper = Clipper2::Clipper64.new
clipper.add_subject([[0, 0], [10, 0], [10, 10], [0, 10]])
clipper.add_clip([[5, 5], [15, 5], [15, 15], [5, 15]])

solution = clipper.execute(Clipper2::INTERSECTION, Clipper2::NON_ZERO)
```

Methods:

- `add_subject(path)` adds one closed subject path.
- `add_subjects(paths)` adds multiple subject paths.
- `add_clip(path)` adds one closed clip path.
- `add_clips(paths)` adds multiple clip paths.
- `add_open_subject(path)` stores one open subject path.
- `add_open_subjects(paths)` stores multiple open subject paths.
- `execute(clip_type, fill_rule = Clipper2::NON_ZERO, solution = nil)` returns paths.
- `execute_polytree(clip_type, fill_rule = Clipper2::NON_ZERO)` returns a `PolyTree`.
- `clear` removes all stored paths.
- `preserve_collinear=` controls collinear trimming.
- `reverse_solution=` reverses output orientation.

### `Clipper2::ClipperD`

Stateful floating-point clipping engine.

```ruby
clipper = Clipper2::ClipperD.new(3)
clipper.add_subject([[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]])
clipper.add_clip([[0.5, 0.5], [1.5, 0.5], [1.5, 1.5], [0.5, 1.5]])

solution = clipper.execute(Clipper2::INTERSECTION)
```

`precision` controls the internal scale factor: `10 ** precision`.

## Offsetting

### `Clipper2.inflate_paths(paths, delta, join_type = Clipper2::SQUARE, end_type = Clipper2::POLYGON, miter_limit = 2.0, arc_tolerance = 0.25)`

Offsets one or more paths.

```ruby
paths = [
  [[0, 0], [10, 0], [10, 10], [0, 10]]
]

expanded = Clipper2.inflate_paths(paths, 2, Clipper2::MITER, Clipper2::POLYGON)
contracted = Clipper2.inflate_paths(paths, -2, Clipper2::SQUARE, Clipper2::POLYGON)
```

### `Clipper2::ClipperOffset`

Stateful offset builder.

```ruby
offset = Clipper2::ClipperOffset.new(2.0, 0.25)
offset.add_path([[0, 0], [10, 0], [10, 10], [0, 10]], Clipper2::ROUND, Clipper2::POLYGON)

solution = offset.execute(2)
```

Methods:

- `add_path(path, join_type = Clipper2::SQUARE, end_type = Clipper2::POLYGON)` adds one path.
- `add_paths(paths, join_type = Clipper2::SQUARE, end_type = Clipper2::POLYGON)` adds many paths.
- `execute(delta, solution = nil)` returns offset paths.
- `clear` removes all queued paths.
- `miter_limit=` sets the maximum miter length.
- `arc_tolerance=` sets round join approximation tolerance.
- `reverse_solution=` reverses output orientation.

## Rectangle Clipping

### `Clipper2.rect_clip(rect, paths)`

Clips closed polygon paths to a rectangle.

```ruby
rect = Clipper2::Rect64.new(left: 0, top: 0, right: 10, bottom: 10)
paths = [
  [[-5, -5], [5, -5], [5, 5], [-5, 5]]
]

Clipper2.rect_clip(rect, paths)
```

`rect` may be a `Rect64`, `RectD`, or an array `[left, top, right, bottom]`.

### `Clipper2.rect_clip_lines(rect, paths)`

Clips open line segments to a rectangle.

```ruby
Clipper2.rect_clip_lines([0, 0, 10, 10], [
  [[-5, 5], [15, 5]]
]).map { |path| path.map(&:to_a) }
# => [[[0, 5], [10, 5]]]
```

### Lower-Level Rectangle Helpers

These are public module functions and can be used directly when needed:

- `normalize_rect(rect)` converts a rectangle-like value to `Rect64`.
- `clip_path_to_rect(path, rect)` clips a single closed path.
- `clip_against_edge(path, inside, intersection)` clips against a custom edge.
- `intersect_vertical(a, b, x)` intersects a segment with a vertical line.
- `intersect_horizontal(a, b, y)` intersects a segment with a horizontal line.
- `clip_segment_to_rect(a, b, rect)` clips a single segment to a rectangle.

## Minkowski Operations

### `Clipper2.minkowski_sum(pattern, path, path_is_closed = true)`

Computes a Minkowski sum and unions the generated quads.

```ruby
pattern = [[0, 0], [1, 0], [1, 1], [0, 1]]
path = [[0, 0], [10, 0], [10, 10], [0, 10]]

Clipper2.minkowski_sum(pattern, path)
```

### `Clipper2.minkowski_diff(pattern, path, path_is_closed = true)`

Computes a Minkowski difference and unions the generated quads.

```ruby
Clipper2.minkowski_diff(pattern, path)
```

### `Clipper2.minkowski_quads(pattern, path, difference, path_is_closed)`

Returns the generated quad paths without unioning them.

```ruby
pattern64 = Clipper2.path64(pattern)
path64 = Clipper2.path64(path)

Clipper2.minkowski_quads(pattern64, path64, false, true)
```

## Triangulation

### `Clipper2.triangulate(paths)`

Triangulates polygon paths and returns a `TriangulateResult`.

```ruby
result = Clipper2.triangulate([
  [[0, 0], [10, 0], [10, 10], [0, 10]]
])

result.triangles.length
# => 2

result.to_a
```

### `Clipper2.triangulate_path(path)`

Triangulates one polygon path and returns an array of `Triangle` objects.

```ruby
triangles = Clipper2.triangulate_path(
  Clipper2.path64([[0, 0], [10, 0], [10, 10], [0, 10]])
)
```

### `Clipper2::Triangle`

Triangle result type.

```ruby
triangle = triangles.first
triangle.a
triangle.b
triangle.c
triangle.to_a
```

### `Clipper2::TriangulateResult`

Triangulation wrapper.

```ruby
result = Clipper2.triangulate([[[0, 0], [10, 0], [10, 10], [0, 10]]])
result.triangles
result.to_a
```

## Testing

Run the test suite:

```sh
bundle exec rake test
```

Or:

```sh
rake test
```

## Current Limitations

This project is a pure Ruby port and does not currently provide full one-to-one parity with the upstream C++ scanline engine.

Known gaps are tracked as skipped tests in `test/`:

- Fixture-backed upstream test files such as `Polygons.txt`, `Lines.txt`, `Offsets.txt`, and `PolytreeHoleOwner*.txt` are not bundled yet.
- Exact nested `PolyTree` hole ownership parity is incomplete.
- Exact upstream self-intersection cleanup and negative fill behavior are incomplete.
- C++ export header serialization is not part of the pure Ruby API.
- C++ benchmark, SVG, Visual Studio, and CMake/pkg-config utilities are represented as skipped coverage tests where they do not apply to Ruby.

## Development

```sh
bundle install
rake test
```

The library is organized by feature:

- `lib/clipper2/core.rb`
- `lib/clipper2/engine.rb`
- `lib/clipper2/offset.rb`
- `lib/clipper2/rect_clip.rb`
- `lib/clipper2/minkowski.rb`
- `lib/clipper2/triangulation.rb`
