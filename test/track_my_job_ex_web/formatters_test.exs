defmodule TrackMyJobExWeb.FormattersTest do
  use ExUnit.Case, async: true

  alias TrackMyJobExWeb.Formatters

  describe "safe_http_url/1" do
    test "returns absolute http and https URLs unchanged" do
      assert Formatters.safe_http_url("https://example.com/jobs/1") ==
               "https://example.com/jobs/1"

      assert Formatters.safe_http_url("http://example.com/jobs/1") ==
               "http://example.com/jobs/1"
    end

    test "rejects non-http schemes" do
      assert Formatters.safe_http_url("javascript:alert(1)") == nil
      assert Formatters.safe_http_url("data:text/html,<script>alert(1)</script>") == nil
      assert Formatters.safe_http_url("file:///etc/passwd") == nil
      assert Formatters.safe_http_url("mailto:jobs@example.com") == nil
    end

    test "rejects relative and malformed URLs" do
      assert Formatters.safe_http_url("/applications") == nil
      assert Formatters.safe_http_url("//example.com/jobs") == nil
      assert Formatters.safe_http_url("example.com/jobs") == nil
      assert Formatters.safe_http_url("not a url") == nil
    end

    test "rejects missing values" do
      assert Formatters.safe_http_url(nil) == nil
      assert Formatters.safe_http_url("") == nil
    end
  end
end
