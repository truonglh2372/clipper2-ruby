require_relative "test_helper"

class UpstreamWindowsTest < Minitest::Test
  def test_windows_header_include
    assert defined?(Clipper2)
  end
end
