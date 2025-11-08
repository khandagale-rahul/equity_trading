# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_08_133022) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_configurations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "api_name", null: false
    t.string "api_key", null: false
    t.string "api_secret", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_token"
    t.datetime "token_expires_at"
    t.string "oauth_state"
    t.datetime "oauth_authorized_at"
    t.string "redirect_uri"
    t.index ["api_name"], name: "index_api_configurations_on_api_name"
    t.index ["user_id", "api_name"], name: "index_api_configurations_on_user_id_and_api_name", unique: true
    t.index ["user_id"], name: "index_api_configurations_on_user_id"
  end

  create_table "holdings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "broker"
    t.string "exchange"
    t.string "trading_symbol"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_holdings_on_user_id"
  end

  create_table "instrument_histories", force: :cascade do |t|
    t.bigint "master_instrument_id", null: false
    t.integer "unit", null: false
    t.integer "interval", null: false
    t.datetime "date", null: false
    t.decimal "open", precision: 10, scale: 2
    t.decimal "high", precision: 10, scale: 2
    t.decimal "low", precision: 10, scale: 2
    t.decimal "close", precision: 10, scale: 2
    t.bigint "volume"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["master_instrument_id", "unit", "interval", "date"], name: "index_instrument_histories_unique", unique: true
    t.index ["master_instrument_id"], name: "index_instrument_histories_on_master_instrument_id"
    t.index ["unit"], name: "index_instrument_histories_on_unit"
  end

  create_table "instruments", force: :cascade do |t|
    t.string "type", null: false
    t.string "symbol"
    t.string "name"
    t.string "exchange"
    t.string "segment"
    t.string "identifier"
    t.string "exchange_token"
    t.decimal "tick_size", precision: 10, scale: 5
    t.integer "lot_size"
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange"], name: "index_instruments_on_exchange"
    t.index ["identifier"], name: "index_instruments_on_identifier"
    t.index ["raw_data"], name: "index_instruments_on_raw_data", using: :gin
    t.index ["symbol"], name: "index_instruments_on_symbol"
    t.index ["type"], name: "index_instruments_on_type"
  end

  create_table "master_instruments", force: :cascade do |t|
    t.string "name"
    t.string "exchange"
    t.string "exchange_token"
    t.decimal "ltp", precision: 10, scale: 2
    t.decimal "previous_day_ltp", precision: 10, scale: 2
    t.integer "zerodha_instrument_id"
    t.integer "upstox_instrument_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["upstox_instrument_id"], name: "index_master_instruments_on_upstox_instrument_id", unique: true
    t.index ["zerodha_instrument_id"], name: "index_master_instruments_on_zerodha_instrument_id", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.string "type", null: false
    t.bigint "user_id", null: false
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.text "message"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_notifications_on_item"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "strategy_id", null: false
    t.bigint "master_instrument_id", null: false
    t.string "type"
    t.integer "instrument_id"
    t.string "instrument_type"
    t.integer "trade_action"
    t.string "broker_order_id"
    t.string "status"
    t.text "status_message"
    t.text "status_message_raw"
    t.string "tradingsymbol"
    t.string "exchange"
    t.datetime "exchange_update_timestamp"
    t.datetime "exchange_timestamp"
    t.string "variety"
    t.string "order_type"
    t.datetime "order_timestamp"
    t.string "product"
    t.string "validity"
    t.integer "validity_ttl"
    t.string "transaction_type"
    t.integer "quantity"
    t.integer "disclosed_quantity"
    t.float "quote_ltp"
    t.float "price"
    t.float "trigger_price"
    t.float "average_price"
    t.integer "filled_quantity"
    t.integer "pending_quantity"
    t.integer "cancelled_quantity"
    t.json "meta"
    t.string "guid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["master_instrument_id"], name: "index_orders_on_master_instrument_id"
    t.index ["strategy_id"], name: "index_orders_on_strategy_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "screeners", force: :cascade do |t|
    t.string "name"
    t.bigint "user_id", null: false
    t.boolean "active", default: false
    t.text "rules"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "scanned_master_instrument_ids", default: [], array: true
    t.datetime "scanned_at"
    t.index ["user_id"], name: "index_screeners_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "strategies", force: :cascade do |t|
    t.string "name"
    t.string "type", null: false
    t.bigint "user_id", null: false
    t.jsonb "parameters", default: {}
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "entry_rule"
    t.text "exit_rule"
    t.integer "master_instrument_ids", default: [], array: true
    t.boolean "deployed", default: false, null: false
    t.integer "re_enter", default: 0, null: false
    t.integer "daily_max_entries", default: 5, null: false
    t.integer "entered_master_instrument_ids", default: [], array: true
    t.boolean "only_simulate", default: false
    t.integer "close_order_ids", default: [], array: true
    t.index ["user_id"], name: "index_strategies_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone_number", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
  end

  create_table "versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.string "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  add_foreign_key "api_configurations", "users"
  add_foreign_key "holdings", "users"
  add_foreign_key "instrument_histories", "master_instruments"
  add_foreign_key "notifications", "users"
  add_foreign_key "orders", "master_instruments"
  add_foreign_key "orders", "strategies"
  add_foreign_key "orders", "users"
  add_foreign_key "screeners", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "strategies", "users"
end
