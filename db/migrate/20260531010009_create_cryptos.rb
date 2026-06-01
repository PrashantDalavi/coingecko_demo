class CreateCryptos < ActiveRecord::Migration[7.2]
  def change
    create_table :cryptos do |t|
      t.string :name
      t.float :price
      t.string :currency_code

      t.timestamps
    end

    add_index :cryptos, :name
    add_index :cryptos, :price
  end
end
