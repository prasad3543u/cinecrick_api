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

ActiveRecord::Schema[8.1].define(version: 2026_03_20_092256) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bookings", force: :cascade do |t|
    t.boolean "balls_ready", default: false
    t.date "booking_date"
    t.datetime "created_at", null: false
    t.bigint "ground_id", null: false
    t.boolean "ground_ready", default: false
    t.string "groundsman_name"
    t.string "groundsman_phone"
    t.string "match_type"
    t.string "payment_status"
    t.bigint "slot_id", null: false
    t.string "status"
    t.decimal "total_price"
    t.boolean "umpire_arranged", default: false
    t.string "umpire_name"
    t.string "umpire_phone"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.boolean "water_arranged", default: false
    t.index ["ground_id"], name: "index_bookings_on_ground_id"
    t.index ["slot_id"], name: "index_bookings_on_slot_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "grounds", force: :cascade do |t|
    t.string "admin_name"
    t.string "admin_phone"
    t.text "amenities"
    t.string "closing_time"
    t.datetime "created_at", null: false
    t.string "image_url"
    t.string "location"
    t.string "name"
    t.string "opening_time"
    t.decimal "price_per_hour"
    t.string "sport_type"
    t.datetime "updated_at", null: false
  end

  create_table "slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "end_time"
    t.bigint "ground_id", null: false
    t.integer "max_teams"
    t.decimal "price"
    t.date "slot_date"
    t.string "start_time"
    t.string "status"
    t.integer "teams_booked_count"
    t.datetime "updated_at", null: false
    t.index ["ground_id"], name: "index_slots_on_ground_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "dob"
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.string "phone"
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "bookings", "grounds"
  add_foreign_key "bookings", "slots"
  add_foreign_key "bookings", "users"
  add_foreign_key "slots", "grounds"
end
