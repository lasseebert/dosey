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

  test "closes day time popups and saves when pressing Enter in a time field" do
    app_js = File.read!(@app_js)

    assert app_js =~ ~s(addEventListener("keydown")
    assert app_js =~ ~s(event.key === "Enter")
    assert app_js =~ ~s([data-day-time-popup])
    assert app_js =~ ~S|closest("[data-day-time-popup]")|
    assert app_js =~ ~S|removeAttribute("open")|
    assert app_js =~ ~S|event.target.blur()|
  end

  test "focuses the day time input when its popup opens" do
    app_js = File.read!(@app_js)

    assert app_js =~ ~s(addEventListener("toggle")
    assert app_js =~ ~S|event.target.matches("[data-day-time-popup]")|
    assert app_js =~ ~s(event.target.open)
    assert app_js =~ ~S|querySelector("[data-time-input]")|
    assert app_js =~ ~S|input.focus()|
  end

  test "places the cursor at the end of the day time input when its popup opens" do
    app_js = File.read!(@app_js)

    assert app_js =~ ~s(const cursorPosition = input.value.length)
    assert app_js =~ ~S|input.setSelectionRange(cursorPosition, cursorPosition)|
  end

  test "closes open day time popups and saves when clicking outside" do
    app_js = File.read!(@app_js)

    assert app_js =~ ~s(addEventListener("pointerdown")
    assert app_js =~ ~S|querySelectorAll("[data-day-time-popup][open]")|
    assert app_js =~ ~S|popup.contains(event.target)|
    assert app_js =~ ~S|popup.querySelector("[data-time-input]")|
    assert app_js =~ ~S|input.blur()|
    assert app_js =~ ~S|popup.removeAttribute("open")|
  end
end
