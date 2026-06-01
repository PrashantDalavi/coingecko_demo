require "rails_helper"

RSpec.describe Crypto, type: :model do
  describe "COINS" do
    it "is a frozen hash of supported coin IDs" do
      expect(Crypto::COINS).to be_frozen
      expect(Crypto::COINS).to include("bitcoin", "ethereum", "solana")
    end
  end

  describe ".permitted_coin_id" do
    it "returns the coin_id if it is a known coin" do
      expect(Crypto.permitted_coin_id("ethereum")).to eq("ethereum")
    end

    it "defaults to bitcoin for unknown coins" do
      expect(Crypto.permitted_coin_id("shiba_inu")).to eq("bitcoin")
    end

    it "handles symbol input by converting to string" do
      expect(Crypto.permitted_coin_id(:solana)).to eq("solana")
    end

    it "handles nil input" do
      expect(Crypto.permitted_coin_id(nil)).to eq("bitcoin")
    end
  end

  describe ".cache_key_for" do
    it "returns a namespaced cache key for a valid coin" do
      expect(Crypto.cache_key_for("ethereum")).to eq("crypto_prices:ethereum")
    end

    it "defaults to bitcoin key for an unknown coin" do
      expect(Crypto.cache_key_for("unknown")).to eq("crypto_prices:bitcoin")
    end
  end

  describe ".payload_for" do
    it "returns a hash with coin details" do
      crypto = create(:crypto, name: "Bitcoin (BTC)", price: 67_500.42, currency_code: "USD")
      payload = Crypto.payload_for("bitcoin", crypto)

      expect(payload).to include(
        id: "bitcoin",
        name: "Bitcoin (BTC)",
        price: 67_500.42,
        currency_code: "USD"
      )
      expect(payload[:updated_at]).to be_present
    end
  end
end
