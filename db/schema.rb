# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20201014015533) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "access_tokens", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "client_id"
    t.bigint "refresh_token_id"
    t.string "token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_access_tokens_on_account_id"
    t.index ["client_id"], name: "index_access_tokens_on_client_id"
    t.index ["refresh_token_id"], name: "index_access_tokens_on_refresh_token_id"
  end

  create_table "account_groups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "account_groups_and_roles", force: :cascade do |t|
    t.bigint "account_group_id"
    t.bigint "role_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_group_id"], name: "index_account_groups_and_roles_on_account_group_id"
    t.index ["role_id"], name: "index_account_groups_and_roles_on_role_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "email"
    t.string "nickname"
    t.string "telephone"
    t.string "password_digest"
    t.string "confirmation_digest"
    t.datetime "confirmed_at"
    t.string "reset_password_digest"
    t.datetime "reset_password_sent_at"
    t.string "remember_digest"
    t.datetime "remember_created_at"
    t.boolean "is_valid"
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "firstname"
    t.string "lastname"
    t.string "sex"
    t.string "country"
    t.string "city"
    t.string "address"
    t.string "company"
    t.string "qq_num"
    t.string "wechat_num"
    t.string "extra_email"
    t.string "memo"
    t.bigint "mp4_id"
  end

  create_table "accounts_and_account_groups", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "account_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_group_id"], name: "index_accounts_and_account_groups_on_account_group_id"
    t.index ["account_id"], name: "index_accounts_and_account_groups_on_account_id"
  end

  create_table "accounts_and_channels", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "channel_id"
    t.index ["account_id"], name: "index_accounts_and_channels_on_account_id"
    t.index ["channel_id"], name: "index_accounts_and_channels_on_channel_id"
  end

  create_table "accounts_and_roles", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "role_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_accounts_and_roles_on_account_id"
    t.index ["role_id"], name: "index_accounts_and_roles_on_role_id"
  end

  create_table "applications", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "authorization_codes", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "client_id"
    t.string "token"
    t.string "redirect_uri"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_authorization_codes_on_account_id"
    t.index ["client_id"], name: "index_authorization_codes_on_client_id"
  end

  create_table "channels", force: :cascade do |t|
    t.string "name"
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "account_id"
    t.string "identifier"
    t.string "secret"
    t.string "name"
    t.string "website"
    t.string "redirect_uri"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_clients_on_account_id"
  end

  create_table "depot_areas", force: :cascade do |t|
    t.bigint "depot_id"
    t.string "area_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["depot_id"], name: "index_depot_areas_on_depot_id"
  end

  create_table "depots", force: :cascade do |t|
    t.bigint "account_id"
    t.string "channel"
    t.string "name"
    t.string "depot_code"
    t.string "country"
    t.string "province"
    t.string "city"
    t.string "district"
    t.string "street"
    t.string "street_number"
    t.string "house_number"
    t.string "postcode"
    t.string "telephone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_depots_on_account_id"
  end

  create_table "inventories", force: :cascade do |t|
    t.bigint "account_id"
    t.string "channel"
    t.string "sku_code"
    t.string "barcode"
    t.integer "quantity", default: 0
    t.integer "available_quantity", default: 0
    t.integer "frozen_quantity", default: 0
    t.string "name"
    t.string "foreign_name"
    t.string "abc_category"
    t.integer "caution_threshold"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_inventories_on_account_id"
  end

  create_table "inventory_infos", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "inventory_id"
    t.string "batch_num"
    t.string "status"
    t.string "sku_code"
    t.string "barcode"
    t.integer "quantity", default: 0
    t.integer "available_quantity", default: 0
    t.integer "frozen_quantity", default: 0
    t.string "shelf_num"
    t.string "depot_code"
    t.datetime "production_date"
    t.datetime "expiry_date"
    t.string "country_of_origin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_inventory_infos_on_account_id"
    t.index ["inventory_id"], name: "index_inventory_infos_on_inventory_id"
  end

  create_table "inventory_operation_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.string "channel"
    t.bigint "inventory_id"
    t.string "operation"
    t.string "sku_code"
    t.string "barcode"
    t.string "batch_num"
    t.string "shelf_num"
    t.integer "quantity"
    t.bigint "operator_id"
    t.string "operator"
    t.string "remark"
    t.bigint "reference_id"
    t.string "status"
    t.string "refer_num"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_inventory_operation_logs_on_account_id"
    t.index ["inventory_id"], name: "index_inventory_operation_logs_on_inventory_id"
  end

  create_table "inventory_settings", force: :cascade do |t|
    t.bigint "account_id"
    t.string "field_key"
    t.string "field_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_inventory_settings_on_account_id"
  end

  create_table "inventory_task_check_infos", force: :cascade do |t|
    t.bigint "inventory_task_id"
    t.bigint "inventory_id"
    t.string "status"
    t.string "shelf_num"
    t.integer "check_quantity"
    t.bigint "operator_id"
    t.string "operator"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id"], name: "index_inventory_task_check_infos_on_inventory_id"
    t.index ["inventory_task_id"], name: "index_inventory_task_check_infos_on_inventory_task_id"
  end

  create_table "inventory_task_check_types", force: :cascade do |t|
    t.bigint "inventory_task_id"
    t.bigint "inventory_id"
    t.string "check_type"
    t.string "shelf_num"
    t.index ["inventory_id"], name: "index_inventory_task_check_types_on_inventory_id"
    t.index ["inventory_task_id"], name: "index_inventory_task_check_types_on_inventory_task_id"
  end

  create_table "inventory_task_transfer_infos", force: :cascade do |t|
    t.bigint "inventory_task_id"
    t.bigint "inventory_id"
    t.string "status"
    t.string "to_depot_code"
    t.string "from_shelf_num"
    t.string "to_shelf_num"
    t.integer "transfer_quantity"
    t.bigint "operator_id"
    t.string "operator"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id"], name: "index_inventory_task_transfer_infos_on_inventory_id"
    t.index ["inventory_task_id"], name: "index_inventory_task_transfer_infos_on_inventory_task_id"
  end

  create_table "inventory_tasks", force: :cascade do |t|
    t.bigint "account_id"
    t.string "channel"
    t.string "task_num"
    t.string "operation"
    t.string "status"
    t.jsonb "operator_ids", default: []
    t.datetime "scheduled_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_inventory_tasks_on_account_id"
  end

  create_table "product_categories", force: :cascade do |t|
    t.string "name"
    t.string "foreign_name"
    t.string "hscode"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_sales_properties", force: :cascade do |t|
    t.bigint "product_id"
    t.string "brand"
    t.string "model"
    t.decimal "price", precision: 10, scale: 2
    t.string "currency"
    t.decimal "weight", precision: 8, scale: 2
    t.jsonb "clearance_attributes", default: {}
    t.string "thumbnail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_sales_properties_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "product_category_id"
    t.bigint "service_category_id"
    t.string "channel"
    t.string "sku_code"
    t.string "barcode"
    t.string "name"
    t.string "foreign_name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_products_on_account_id"
    t.index ["product_category_id"], name: "index_products_on_product_category_id"
    t.index ["service_category_id"], name: "index_products_on_service_category_id"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "client_id"
    t.string "token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_refresh_tokens_on_account_id"
    t.index ["client_id"], name: "index_refresh_tokens_on_client_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.string "name_zh_cn"
    t.string "description"
    t.bigint "application_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_roles_on_application_id"
  end

  create_table "service_categories", force: :cascade do |t|
    t.string "name"
    t.string "foreign_name"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shelf_infos", force: :cascade do |t|
    t.bigint "shelf_id"
    t.string "shelf_num"
    t.integer "column"
    t.integer "row"
    t.string "spec"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shelf_id"], name: "index_shelf_infos_on_shelf_id"
  end

  create_table "shelves", force: :cascade do |t|
    t.bigint "depot_id"
    t.bigint "depot_area_id"
    t.string "depot_code"
    t.string "area_code"
    t.integer "seq"
    t.integer "column_number"
    t.integer "row_number"
    t.string "spec"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["depot_area_id"], name: "index_shelves_on_depot_area_id"
    t.index ["depot_id"], name: "index_shelves_on_depot_id"
  end

end
