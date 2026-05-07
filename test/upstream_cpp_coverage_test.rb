require_relative "test_helper"

class UpstreamCppCoverageTest < Minitest::Test
  def test_cpp_cmake_lists
    skip "CMake build configuration is not applicable to the pure Ruby gem"
  end

  def test_cpp_pkg_config_template
    skip "pkg-config metadata is not applicable to the pure Ruby gem"
  end

  def test_cpp_clipper_config_template
    skip "CMake package config metadata is not applicable to the pure Ruby gem"
  end

  def test_cpp_version_template
    skip "C++ version template is represented by Clipper2::VERSION in Ruby"
  end

  def test_google_test_visual_studio_notes
    skip "Visual Studio GoogleTest setup documentation is not applicable to Ruby Minitest"
  end

  def test_benchmark_get_intersect_point
    skip "C++ microbenchmark coverage requires a Ruby benchmark harness"
  end

  def test_benchmark_point_in_polygon
    skip "C++ microbenchmark coverage requires a Ruby benchmark harness"
  end

  def test_benchmark_strip_duplicate
    skip "C++ microbenchmark coverage requires a Ruby benchmark harness"
  end

  def test_examples_benchmarks
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_inflate
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_mem_leak_test
    skip "C++ memory leak sample is not applicable to pure Ruby"
  end

  def test_examples_polygon_samples
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_random_clipping
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_rect_clipping
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_simple_clipping
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_triangulation
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_union_clipping
    skip "example application conversion is outside the current test parity scope"
  end

  def test_examples_using_z
    skip "USINGZ callback parity is not implemented in the pure Ruby port"
  end

  def test_examples_variable_offset
    skip "variable offset callback parity is not implemented in the pure Ruby port"
  end

  def test_utils_clip_file_load
    skip "ClipFileLoad fixture parser is not yet ported to Ruby"
  end

  def test_utils_clip_file_save
    skip "ClipFileSave fixture writer is not yet ported to Ruby"
  end

  def test_utils_colors
    skip "C++ color constants are only used by SVG/example helpers"
  end

  def test_utils_common_utils
    skip "C++ example utility helpers are not part of the Ruby public API"
  end

  def test_utils_timer
    skip "C++ timer utility is not part of the Ruby public API"
  end

  def test_utils_svg
    skip "SVG writer and viewer utilities are not yet ported to Ruby"
  end

  def test_utils_svg_helpers
    skip "SVG helper utilities are not yet ported to Ruby"
  end
end
