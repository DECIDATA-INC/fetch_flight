defmodule FetchFlight.Client do
  @url "https://www.google.com/travel/flights"

  @headers [
    {"User-Agent",
     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"},
    {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
    {"Accept-Language", "en-US,en;q=0.9"}
  ]

  # Do not set Accept-Encoding by hand: Req negotiates compression itself and,
  # since 0.6, leaves the body compressed when the caller sets that header.

  @price_graph_url "https://www.google.com/_/FlightsFrontendUi/data/travel.frontend.flights.FlightsFrontendService/GetCalendarGraph"

  @price_graph_params [
    {"f.sid", "-8920707734915550076"},
    {"bl", "boq_travel-frontend-ui_20230627.07_p1"},
    {"hl", "en"},
    {"soc-app", "162"},
    {"soc-platform", "1"},
    {"soc-device", "1"},
    {"_reqid", "261464"},
    {"rt", "c"}
  ]

  # x-goog-ext-259736195-jspb is a capability bitmask sent to the Google Flights
  # internal API. The feature IDs were extracted from the Go reference implementation
  # at krisukox/google-flights-api. If Google rotates this header, requests will return 403.
  @price_graph_headers [
    {"Content-Type", "application/x-www-form-urlencoded;charset=UTF-8"},
    {"x-goog-ext-259736195-jspb",
     ~s(["en-US","US","USD",1,null,[-120],null,[[48764689,47907128,48676280,48710756,48627726,48480739,48593234,48707380]],1,[]])},
    {"User-Agent",
     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"},
    {"Accept-Language", "en-US,en;q=0.9"}
  ]

  @doc """
  Fetch Google Flights HTML for the given tfs parameter.

  `country` (ISO 3166-1 alpha-2, e.g. `"BR"`) is sent as `gl`: it sets the
  point of sale, so fares and currency conversion match what a buyer in that
  country sees. Without it Google guesses the country from the caller's IP,
  and a server abroad gets fares from another market converted to `currency`.

  Returns `{:ok, html_body}` or `{:error, reason}`.
  """
  # tfu is a Google Flights capability flag. "EgQIABABIgA" enables full airline
  # price results; omitting it or using other values returns fewer results.
  @tfu "EgQIABABIgA"

  def fetch(tfs_param, language \\ "en", currency \\ "USD", country \\ nil) do
    case Req.get(@url,
           params: request_params(tfs_param, language, currency, country),
           headers: request_headers(language)
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def request_params(tfs_param, language, currency, country) do
    params = [tfs: tfs_param, hl: language, curr: currency, tfu: @tfu]
    if country in [nil, ""], do: params, else: params ++ [gl: country]
  end

  @doc false
  # Accept-Language follows `hl`, so the page and the point of sale agree.
  def request_headers(language) do
    @headers
    |> List.keydelete("Accept-Language", 0)
    |> Kernel.++([{"Accept-Language", accept_language(language)}])
  end

  defp accept_language(language) when language in [nil, "", "en", "en-US"], do: "en-US,en;q=0.9"

  defp accept_language(language) do
    [primary | _] = String.split(language, "-")
    "#{language},#{primary};q=0.9"
  end

  @doc """
  POST to the GetCalendarGraph endpoint with a pre-built form body.
  Returns `{:ok, body}` or `{:error, reason}`.
  """
  def fetch_price_graph(form_body) do
    case Req.post(@price_graph_url,
           params: @price_graph_params,
           headers: @price_graph_headers,
           body: form_body,
           decode_body: false
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end
end
