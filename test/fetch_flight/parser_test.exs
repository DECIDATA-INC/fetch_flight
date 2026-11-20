defmodule FetchFlight.ParserTest do
  use ExUnit.Case, async: true

  alias FetchFlight.Parser

  # Minimal HTML fixture that mirrors the structure Google Flights embeds.
  # The ds:1 script contains AF_initDataCallback({...data:[<payload>]...}).
  @alliances_data [[["*A", "Star Alliance"], ["OW", "Oneworld"]]]
  @airlines_data [[["UA", "United Airlines"], ["AA", "American Airlines"]]]

  defp build_payload do
    # payload[3][0] = flight rows
    # payload[7][1][0] = alliances, payload[7][1][1] = airlines
    single_flight = List.duplicate(nil, 23)

    single_flight =
      single_flight
      |> List.replace_at(3, "SFO")
      |> List.replace_at(4, "San Francisco International")
      |> List.replace_at(5, "John F. Kennedy International")
      |> List.replace_at(6, "JFK")
      |> List.replace_at(8, [8])
      |> List.replace_at(10, [16, 30])
      |> List.replace_at(11, 330)
      |> List.replace_at(17, "Boeing 737")
      |> List.replace_at(20, [2026, 3, 15])
      |> List.replace_at(21, [2026, 3, 15])
      |> List.replace_at(22, ["UA", "1234", nil, "United"])

    carbon_extras =
      List.duplicate(nil, 9) |> List.replace_at(7, 180_000) |> List.replace_at(8, 200_000)

    flight = ["Best", ["UA"], [single_flight]] ++ List.duplicate(nil, 19) ++ [carbon_extras]
    row = [flight, [["$350", 350, "USD"]]]

    # Build sparse top-level payload using nil padding
    # Index 3 → flight rows, index 7 → metadata
    meta_section = [nil, [@alliances_data |> hd(), @airlines_data |> hd()]]

    payload = List.duplicate(nil, 8)
    payload = List.replace_at(payload, 3, [[row]])
    payload = List.replace_at(payload, 7, meta_section)
    payload
  end

  defp build_html(payload) do
    json = Jason.encode!(payload)

    """
    <html>
    <head></head>
    <body>
    <script class="ds:1">AF_initDataCallback({key: 'ds:1', data:#{json},null});</script>
    </body>
    </html>
    """
  end

  test "returns error for missing ds:1 script" do
    assert {:error, :ds1_script_not_found} = Parser.parse("<html></html>")
  end

  test "returns error when data key is missing" do
    html = ~s(<html><body><script class="ds:1">no data here</script></body></html>)
    assert {:error, :data_key_not_found} = Parser.parse(html)
  end

  test "parses metadata (airlines and alliances)" do
    html = build_html(build_payload())
    assert {:ok, {meta, _flights}} = Parser.parse(html)
    assert length(meta.alliances) == 2
    assert length(meta.airlines) == 2
    assert hd(meta.alliances).code == "*A"
    assert hd(meta.airlines).code == "UA"
  end

  test "parses flight results" do
    html = build_html(build_payload())
    assert {:ok, {_meta, flights}} = Parser.parse(html)
    assert length(flights) > 0
  end

  test "parses single flight legs" do
    html = build_html(build_payload())
    assert {:ok, {_meta, [first | _]}} = Parser.parse(html)
    assert length(first.flights) == 1
    leg = hd(first.flights)
    assert leg.from_airport.code == "SFO"
    assert leg.to_airport.code == "JFK"
    assert leg.duration_minutes == 330
    assert leg.plane_type == "Boeing 737"
    assert leg.departure.date == ~D[2026-03-15]
    assert leg.departure.time == ~T[08:00:00]
    assert leg.arrival.time == ~T[16:30:00]
    assert leg.airline_code == "UA"
    assert leg.flight_number == "1234"
  end

  test "parses carbon emissions" do
    html = build_html(build_payload())
    assert {:ok, {_meta, [first | _]}} = Parser.parse(html)
    assert first.carbon.emission_grams == 180_000
    assert first.carbon.typical_on_route_grams == 200_000
  end

  test "returns empty flights when payload[3][0] is nil" do
    payload = List.duplicate(nil, 8)
    meta = [nil, [[], []]]
    payload = List.replace_at(payload, 3, [[nil]])
    payload = List.replace_at(payload, 7, meta)
    html = build_html(payload)
    assert {:ok, {_meta, []}} = Parser.parse(html)
  end

  describe "Google Flights real response (GRU-FOR, 2026-12-10, nonstop)" do
    setup do
      {:ok, html: File.read!("test/fixtures/gru_for_2026_12_10.html")}
    end

    # Top flights (payload[2][0]) holds the cheapest options, which are absent
    # from All flights (payload[3][0]); fast-flights (Python) drops them.
    test "merges top and all flights, deduplicated by legs, not by price", %{html: html} do
      assert {:ok, {_meta, flights}} = Parser.parse(html)

      numbers =
        for f <- flights, leg <- f.flights, do: leg.airline_code <> leg.flight_number

      assert Enum.sort(numbers) ==
               ~w(G31554 G31558 LA3318 LA3320 LA3324 LA3360 LA3506 LA3682 LA4776)
    end

    test "normalizes hour-only and minute-only times", %{html: html} do
      assert {:ok, {_meta, flights}} = Parser.parse(html)
      legs = Map.new(for f <- flights, leg <- f.flights, do: {leg.flight_number, leg})

      assert legs["3682"].departure.time == ~T[07:00:00]
      assert legs["3682"].arrival.time == ~T[10:25:00]
      assert legs["1554"].departure.time == ~T[08:35:00]
      assert legs["3682"].departure.date == ~D[2026-12-10]
      # red-eye: leaves on the 10th, lands on the 11th
      assert legs["3324"].arrival.date == ~D[2026-12-11]
    end
  end

  test "expands time pairs that omit zero components" do
    assert Parser.to_time([8]) == ~T[08:00:00]
    assert Parser.to_time([nil, 31]) == ~T[00:31:00]
    assert Parser.to_time([17, 25]) == ~T[17:25:00]
    assert Parser.to_time(nil) == nil
  end

  test "returns :no_flights when Google answers with an error status" do
    html =
      ~s[<html><body><script class="ds:1">AF_initDataCallback({key: 'ds:1', data:null, errorHasStatus: true, sideChannel: {}});</script></body></html>]

    assert {:error, :no_flights} = Parser.parse(html)
  end
end
