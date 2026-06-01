class HomeController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json { render json: crypto_price_response }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Price is not available yet. Please wait for the background job to refresh it." }, status: :not_found
  rescue Faraday::Error, JSON::ParserError
    render json: { error: "Unable to fetch the price right now." }, status: :bad_gateway
  end

  private

  def crypto_price_response
    coin_id = Crypto.permitted_coin_id(params[:crypto_id])
    cached_payload = read_cached_price(coin_id)

    cached_payload.presence || crypto_price_from_db(coin_id)
  end

  def read_cached_price(coin_id)
    Rails.cache.read(Crypto.cache_key_for(coin_id))
  rescue StandardError => error
    Rails.logger.warn("Cache read failed: #{error.class} - #{error.message}")
    nil
  end

  def crypto_price_from_db(coin_id)
    crypto = Crypto.find_by!(name: Crypto::COINS.fetch(coin_id))
    Crypto.payload_for(coin_id, crypto)
  end
end
