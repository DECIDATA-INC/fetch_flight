defmodule FetchFlight.ClientTest do
  use ExUnit.Case, async: true

  alias FetchFlight.Client

  describe "request_params/4" do
    test "sends gl when a country is given" do
      params = Client.request_params("tfs123", "pt-BR", "BRL", "BR")

      assert params[:gl] == "BR"
      assert params[:hl] == "pt-BR"
      assert params[:curr] == "BRL"
      assert params[:tfs] == "tfs123"
    end

    test "omits gl when no country is given (Google falls back to IP geolocation)" do
      params = Client.request_params("tfs123", "en", "USD", nil)

      refute Keyword.has_key?(params, :gl)
    end
  end

  describe "request_headers/1" do
    test "Accept-Language follows the requested language" do
      headers = Client.request_headers("pt-BR")

      assert {"Accept-Language", "pt-BR,pt;q=0.9"} in headers
    end

    test "keeps the English default" do
      assert {"Accept-Language", "en-US,en;q=0.9"} in Client.request_headers("en")
    end
  end

  describe "FetchFlight.link/4" do
    test "carries the country so the link opens the same search" do
      assert FetchFlight.link("tfs123", "pt-BR", "BRL", "BR") ==
               "https://www.google.com/travel/flights?tfs=tfs123&hl=pt-BR&curr=BRL&gl=BR"
    end

    test "has no gl without a country" do
      assert FetchFlight.link("tfs123", "en", "USD", nil) ==
               "https://www.google.com/travel/flights?tfs=tfs123&hl=en&curr=USD"
    end
  end
end
