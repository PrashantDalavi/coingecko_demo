require "rails_helper"

RSpec.describe CryptoPriceRefreshJob, type: :job do
  let(:coin_id) { "bitcoin" }
  let(:coin_name) { "Bitcoin (BTC)" }
  let(:price) { 67_500.42 }
  let(:api_response_body) do
    Crypto::COINS.keys.each_with_object({}) do |id, hash|
      hash[id] = { "usd" => price }
    end.to_json
  end

  let(:successful_response) do
    instance_double(Faraday::Response, success?: true, body: api_response_body)
  end

  let(:failed_response) do
    instance_double(Faraday::Response, success?: false, body: "")
  end

  before do
    allow(Rails.application.credentials).to receive(:API_KEY).and_return("test-key")
  end

  describe "#perform" do
    context "when the API returns valid prices" do
      before do
        allow(Faraday).to receive(:get).and_return(successful_response)
      end

      it "creates a new crypto record if one does not exist" do
        expect { described_class.perform_now }.to change(Crypto, :count).by(Crypto::COINS.size)
      end

      it "updates an existing crypto record" do
        crypto = create(:crypto, name: coin_name, price: 50_000.00)

        described_class.perform_now

        expect(crypto.reload.price).to eq(price)
      end

      it "writes the payload to the cache" do
        described_class.perform_now

        Crypto::COINS.each_key do |id|
          cached = Rails.cache.read(Crypto.cache_key_for(id))
          expect(cached).to be_present
          expect(cached[:price]).to eq(price)
        end
      end
    end

    context "when the API request fails" do
      before do
        allow(Faraday).to receive(:get).and_raise(Faraday::Error, "connection failed")
      end

      it "raises the error and does not create records" do
        expect { described_class.perform_now }.to raise_error(Faraday::Error)
        expect(Crypto.count).to eq(0)
      end
    end

    context "when the API returns a non-success status" do
      before do
        allow(Faraday).to receive(:get).and_return(failed_response)
      end

      it "raises a Faraday::Error" do
        expect { described_class.perform_now }.to raise_error(Faraday::Error, "CoinGecko request failed")
      end
    end

    context "when the API response body is malformed" do
      let(:malformed_response) do
        instance_double(Faraday::Response, success?: true, body: '{"bitcoin": {}}')
      end

      before do
        allow(Faraday).to receive(:get).and_return(malformed_response)
      end

      it "raises a RuntimeError for missing price" do
        expect { described_class.perform_now }.to raise_error(RuntimeError, /CoinGecko price unavailable/)
      end
    end

    context "when the cache write fails" do
      before do
        allow(Faraday).to receive(:get).and_return(successful_response)
        allow(Rails.cache).to receive(:write).and_raise(Redis::ConnectionError, "cache down")
      end

      it "still persists the record to the database" do
        described_class.perform_now

        crypto = Crypto.find_by(name: coin_name)
        expect(crypto).to be_present
        expect(crypto.price).to eq(price)
      end

      it "logs a warning" do
        allow(Rails.logger).to receive(:warn)

        described_class.perform_now

        expect(Rails.logger).to have_received(:warn).with(/Cache write failed/).at_least(:once)
      end
    end
  end
end
