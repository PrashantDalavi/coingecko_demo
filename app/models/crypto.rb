class Crypto < ApplicationRecord
  COINS = {
    "bitcoin" => "Bitcoin (BTC)",
    "ethereum" => "Ethereum (ETH)",
    "solana" => "Solana (SOL)",
    "ripple" => "XRP (XRP)",
    "cardano" => "Cardano (ADA)",
    "dogecoin" => "Dogecoin (DOGE)"
  }.freeze

  CURRENCY_CODE = "USD"

  def self.permitted_coin_id(coin_id)
    coin_id = coin_id.to_s
    COINS.key?(coin_id) ? coin_id : "bitcoin"
  end

  def self.cache_key_for(coin_id)
    "crypto_prices:#{permitted_coin_id(coin_id)}"
  end

  def self.payload_for(coin_id, crypto)
    {
      id: permitted_coin_id(coin_id),
      name: crypto.name,
      price: crypto.price,
      currency_code: crypto.currency_code,
      updated_at: crypto.updated_at&.iso8601
    }
  end
end
