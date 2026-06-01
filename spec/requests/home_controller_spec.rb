require "rails_helper"

RSpec.describe HomeController, type: :request do
  let(:coin_id) { "bitcoin" }
  let(:coin_name) { "Bitcoin (BTC)" }
  let(:price) { 67_500.42 }

  let(:cached_payload) do
    { id: coin_id, name: coin_name, price: price, currency_code: "USD", updated_at: Time.current.iso8601 }
  end

  describe "GET /crypto_price" do
    context "when the price is in the cache" do
      before do
        Rails.cache.write(Crypto.cache_key_for(coin_id), cached_payload)
      end

      it "returns the cached price" do
        get crypto_price_path, params: { crypto_id: coin_id }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["price"]).to eq(price)
        expect(body["id"]).to eq(coin_id)
      end
    end

    context "when the cache is empty but the DB has the record" do
      before do
        Rails.cache.clear
        create(:crypto, name: coin_name, price: price)
      end

      it "falls back to the database" do
        get crypto_price_path, params: { crypto_id: coin_id }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["price"]).to eq(price)
      end
    end

    context "when neither cache nor DB has the record" do
      before do
        Rails.cache.clear
      end

      it "returns a 404 with a helpful message" do
        get crypto_price_path, params: { crypto_id: coin_id }

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to include("not available yet")
      end
    end

    context "when the cache read raises an error" do
      before do
        create(:crypto, name: coin_name, price: price)
        allow(Rails.cache).to receive(:read).and_raise(StandardError, "cache broken")
      end

      it "falls back to the database gracefully" do
        get crypto_price_path, params: { crypto_id: coin_id }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["price"]).to eq(price)
      end
    end

    context "when an unknown crypto_id is requested" do
      before do
        create(:crypto, name: "Bitcoin (BTC)", price: price)
        Rails.cache.clear
      end

      it "defaults to bitcoin" do
        get crypto_price_path, params: { crypto_id: "unknown_coin" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["id"]).to eq("bitcoin")
      end
    end
  end
end
