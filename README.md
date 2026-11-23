# FetchFlight

[![Hex.pm](https://img.shields.io/hexpm/v/fetch_flight.svg)](https://hex.pm/packages/fetch_flight)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/fetch_flight)

Elixir port of the Python [`fast_flights`](https://github.com/AWeirdDev/flights) library. Scrapes Google Flights by encoding a query as a protobuf binary, fetching the results page, and returning structured flight data — no API key required.

Two entry points:

- `get_flights/2` — fetch specific itineraries for a given date
- `get_price_graph/1` — fetch a calendar of cheapest prices across a date range

## Installation

```elixir
def deps do
  [
    {:fetch_flight, "~> 0.5"}
  ]
end
```

`get_price_graph/1` drives a headless Chromium through the optional
`:playwright` dependency. Add `{:playwright, "~> 1.49.1-alpha.2"}` to your deps
only if you use it; without it, `get_flights/2` works and `get_price_graph/1`
returns `{:error, :playwright_not_installed}`.

## Usage

### `get_flights/2` — flight search

```elixir
query = %{
  data: [
    %{
      date: "2026-05-01",
      from_airport: %{code: "SFO"},
      to_airport: %{code: "JFK"},
      max_stops: nil,
      airlines: []
    }
  ],
  seat: :economy,
  trip: :one_way,
  passengers: [:adult]
}

{:ok, {metadata, flights}} = FetchFlight.get_flights(query)
```

### Options

```elixir
FetchFlight.get_flights(query, language: "pt-BR", currency: "BRL", country: "BR")
```

| Option | Default | Description |
|--------|---------|-------------|
| `:language` | `"en"` | BCP 47 language tag (also sets `Accept-Language`) |
| `:currency` | `"USD"` | ISO 4217 currency code |
| `:country` | none | ISO 3166-1 alpha-2 point of sale, sent as `gl`. Without it Google infers the country from the caller's IP, so a server abroad sees another market's fares converted to `:currency`. |

### Query fields

**Top-level**

| Field | Type | Values |
|-------|------|--------|
| `:seat` | atom | `:economy`, `:premium_economy`, `:business`, `:first` |
| `:trip` | atom | `:one_way`, `:round_trip`, `:multi_city` |
| `:passengers` | `[atom]` | `:adult`, `:child`, `:infant_in_seat`, `:infant_on_lap` |
| `:data` | `[flight_data]` | One entry per leg |

**Per leg (`data` list)**

| Field | Type | Notes |
|-------|------|-------|
| `:date` | `"YYYY-MM-DD"` | Departure date |
| `:from_airport` | `%{code: "SFO"}` | IATA origin code |
| `:to_airport` | `%{code: "JFK"}` | IATA destination code |
| `:max_stops` | `integer \| nil` | `nil` = any number of stops |
| `:airlines` | `[String.t()]` | Filter by IATA airline code, e.g. `["UA", "AA"]` |
| `:departure_time` | `{0..23, 0..23}` | Earliest and latest departure hour, e.g. `{6, 12}` |
| `:arrival_time` | `{0..23, 0..23}` | Earliest and latest arrival hour, e.g. `{14, 23}` |

### Multi-city example

```elixir
query = %{
  data: [
    %{date: "2026-06-01", from_airport: %{code: "SFO"}, to_airport: %{code: "LHR"}, max_stops: nil, airlines: []},
    %{date: "2026-06-10", from_airport: %{code: "LHR"}, to_airport: %{code: "CDG"}, max_stops: 0,   airlines: []}
  ],
  seat: :business,
  trip: :multi_city,
  passengers: [:adult, :adult]
}
```

### `get_price_graph/1` — price calendar

Returns the cheapest price for each departure date in a range — useful for finding the best days to fly.

```elixir
query = %{
  range_start_date: "2026-05-01",
  range_end_date:   "2026-05-31",
  trip_length:      7,
  src_airports:     ["SFO"],
  dst_airports:     ["JFK"]
}

{:ok, offers} = FetchFlight.get_price_graph(query)

# With a different currency
{:ok, offers} = FetchFlight.get_price_graph(query, currency: "EUR")

# With time filters (afternoon departures, evening arrivals)
{:ok, offers} = FetchFlight.get_price_graph(%{query | departure_time: {12, 18}, arrival_time: {14, 23}})
```

### Options

```elixir
FetchFlight.get_price_graph(query, currency: "EUR")
```

| Option | Default | Description |
|--------|---------|-------------|
| `:currency` | `"USD"` | ISO 4217 currency code |

Results are sorted by `start_date` ascending:

```
[
  %FetchFlight.PriceGraphOffer{start_date: "2026-04-17", return_date: "2026-04-24", price: 219.0},
  %FetchFlight.PriceGraphOffer{start_date: "2026-04-18", return_date: "2026-04-25", price: 246.0},
  %FetchFlight.PriceGraphOffer{start_date: "2026-05-01", return_date: "2026-05-08", price: 231.0},
  ...
]
```

> **Note:** Google's Price graph covers roughly ±5 weeks around the search date, so results may extend slightly outside the requested range.

#### Price graph query fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `:range_start_date` | `"YYYY-MM-DD"` | yes | First departure date to check |
| `:range_end_date` | `"YYYY-MM-DD"` | yes | Last departure date to check |
| `:trip_length` | `integer` | yes | Length of stay in days |
| `:src_airports` | `[String.t()]` | one of src/dst required | Origin IATA codes |
| `:src_cities` | `[String.t()]` | one of src/dst required | Origin city names |
| `:dst_airports` | `[String.t()]` | one of src/dst required | Destination IATA codes |
| `:dst_cities` | `[String.t()]` | one of src/dst required | Destination city names |
| `:trip` | atom | no | `:round_trip` (default), `:one_way` |
| `:seat` | atom | no | `:economy` (default), `:premium_economy`, `:business`, `:first` |
| `:passengers` | `[atom]` | no | Same values as `get_flights/2`, defaults to `[:adult]` |
| `:stops` | atom | no | `:any` (default), `:nonstop`, `:one_stop`, `:two_stops` |
| `:departure_time` | `{0..23, 0..23}` | no | Earliest and latest departure hour, e.g. `{6, 12}` |
| `:arrival_time` | `{0..23, 0..23}` | no | Earliest and latest arrival hour, e.g. `{14, 23}` |

## Output

### `get_flights/2`

```elixir
{:ok, {%FetchFlight.JsMetadata{airlines: [...], alliances: [...]}, flights}}
```

`flights` is a list of `%FetchFlight.Flights{}`, sorted cheapest first:

```
%FetchFlight.Flights{
  type:     "DL",                      # IATA carrier code
  price:    344,                       # in the requested currency
  airlines: ["Delta"],
  carbon: %FetchFlight.CarbonEmission{
    emission_grams:          284_000,
    typical_on_route_grams:  354_000
  },
  flights: [
    %FetchFlight.SingleFlight{
      from_airport: %FetchFlight.Airport{code: "SFO", name: "San Francisco International Airport"},
      to_airport:   %FetchFlight.Airport{code: "JFK", name: "John F. Kennedy International Airport"},
      departure: %FetchFlight.SimpleDatetime{date: ~D[2026-05-01], time: ~T[07:00:00]},
      arrival:   %FetchFlight.SimpleDatetime{date: ~D[2026-05-01], time: ~T[15:28:00]},
      duration_minutes: 328,
      plane_type: "Boeing 767",
      airline_code: "DL",
      airline_name: "Delta",
      flight_number: "1234"
    }
  ]
}
```

**`SimpleDatetime` format**
- `:date` — `Date`
- `:time` — `Time`, local to the airport (Google omits zero components; they are expanded)

Results merge Google's "Top flights" and "All flights" blocks (the cheapest
options often appear only in the first) and are deduplicated by legs.

### `get_price_graph/1`

```elixir
{:ok, [%FetchFlight.PriceGraphOffer{}, ...]}
```

Each `%FetchFlight.PriceGraphOffer{}` has:

| Field | Type | Description |
|-------|------|-------------|
| `:start_date` | `String.t()` | Departure date (`"YYYY-MM-DD"`) |
| `:return_date` | `String.t()` | Return date (`"YYYY-MM-DD"`), `nil` for one-way |
| `:price` | `float()` | Cheapest price found for that departure date |

## How it works

### `get_flights/2`

1. **Encode** — the query is serialized as a protobuf binary (manually encoded, no generated code) and Base64-encoded into the `tfs` URL parameter.
2. **Fetch** — `GET https://www.google.com/travel/flights?tfs=...&hl=...&curr=...` with realistic browser headers via [`req`](https://github.com/wojtekmach/req).
3. **Parse** — [`floki`](https://github.com/philss/floki) locates the `<script class="ds:1">` tag; [`jason`](https://github.com/michalmuskala/jason) decodes the embedded JSON payload; specific array indices are navigated to extract flights, prices, and carbon data.

### `get_price_graph/1`

1. **Encode** — the query (both outbound and return legs) is serialized as a protobuf binary and Base64-encoded into the `tfs` URL parameter, same as `get_flights/2`. Including both legs tells Google the intended trip length.
2. **Navigate** — a headless Chromium browser (via [`playwright`](https://hex.pm/packages/playwright)) loads the Google Flights results page, dismisses any deal popup, scrolls to the "Prices for nearby dates" section, and clicks the "Price graph" tab.
3. **Intercept** — a response listener captures the `GetCalendarGraph` XHR that fires when the Price graph tab is clicked. This endpoint returns ~10 weeks of daily prices, one entry per departure date at exactly the requested trip length.
4. **Parse** — the response (prefixed with `)]}'\n`) is decoded with `jason`. The outer envelope is unwrapped, the inner JSON string is decoded, and `[departure_date, return_date, [[null, price], token], 1]` entries are filtered to the requested date range and sorted by departure date.

## Disclaimer

This library scrapes a public web interface. Google may change the page structure without notice, which could break parsing. It is intended for personal and research use — check Google's Terms of Service before deploying at scale.

## License

MIT
