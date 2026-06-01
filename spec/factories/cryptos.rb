FactoryBot.define do
  factory :crypto do
    name { "Bitcoin (BTC)" }
    price { 67_500.42 }
    currency_code { "USD" }
  end
end
