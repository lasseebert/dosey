defmodule DoseyWeb.AppJavaScriptTest do
  use ExUnit.Case, async: true

  @app_js Path.expand("../../../assets/js/app.js", __DIR__)

  test "connects the LiveView client" do
    app_js = File.read!(@app_js)

    assert app_js =~ ~r/^import \{Socket\} from "phoenix"/m
    assert app_js =~ ~r/^import \{LiveSocket\} from "phoenix_live_view"/m
    assert app_js =~ ~r/^const liveSocket = new LiveSocket/m
    assert app_js =~ ~r/^liveSocket\.connect\(\)/m
  end

  test "normalizes loose time fields on blur" do
    app_js = File.read!(@app_js)

    assert app_js =~ "normalizeLooseTime"
    assert app_js =~ ~s([data-time-input])
    assert app_js =~ ~s(addEventListener("blur")
  end
end
