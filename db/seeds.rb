
# 1. create application & roles
application = Application.find_or_create_by(name: 'wms_europe_time')
role_list = {
  super_admin: '超级管理员',
  admin: '软件管理员',
  staff: '工作人员',
  wh_admin: '仓库管理员',
  wh_staff: '仓库工作人员',
  consignor: '货主',
  c_staff: '货主工作人员'
}.stringify_keys

role_list.each do |key, value|
  application.roles.find_or_create_by(name: key, name_zh_cn: value)
end

# 2. create account_group
account_group = AccountGroup.find_or_create_by(name: 'wms')

# 3. create_channel
channel = Channel.find_or_create_by(name: 'QUAIE')

# 4. create account
account = Account.find_by_email('lifuyuan@lifuyuan.com')
if account.nil?
  account = Account.create(
    email: 'lifuyuan@lifuyuan.com',
    mp4_id: 25854,
    nickname: 'lifuyuan',
    password: '1qaz2wsx',
    password_confirmation: '1qaz2wsx',
    confirmed_at: Time.now.utc,
    role_ids: [ Role.where(name: 'super_admin').first.id ],
    account_group_ids: [account_group.id],
    channel_ids: [channel.id]
  )
end

# 4. create client
Client.find_or_create_by(
  name: 'wms_europe_time',
  identifier: 'NSnc8CK3ceqozl8vlwi46A',
  secret: 'h-_hEIFPWZoVUZjWcNIKrzO208VC56P7KI41gMW1IAtED8r1RYx_b63i24EgjlOVg8ZQkqmqyUuQe57_arLYSQ'
)

# 5. create product related data

# ServiceCategory seeds
service_category_names = %w[WMS]
service_category_names.each do |name|
  sc = ServiceCategory.where(name: name).first
  ServiceCategory.create!(name: name, foreign_name: name) if sc.nil?
end


# import ProductCategory from /public/xlsx/product_category_tree.xlsx
file_path = Padrino.root('/public/xlsx/product_category_tree.xlsx')
xlsx      = Roo::Spreadsheet.open(file_path)
sheet     = xlsx.sheet(0)

ActiveRecord::Base.transaction do
  2.upto(sheet.last_row) do |i|
    row = sheet.row(i)
    # check grade 1
    grade_1 = ProductCategory.where(foreign_name: row[0], name: row[1]).first
    grade_1 = ProductCategory.create(foreign_name: row[0], name: row[1]) unless grade_1
    # check grade 2
    grade_2 = ProductCategory.where(foreign_name: row[2], name: row[3], parent_id: grade_1).first
    grade_2 = ProductCategory.create(foreign_name: row[2], name: row[3], parent_id: grade_1.id) unless grade_2
    # check grade 3
    grade_3 = ProductCategory.where(name: row[5], parent_id: grade_2).first
    ProductCategory.create(foreign_name: row[4], name: row[5], parent_id: grade_2.id) unless grade_3
  end

  # 创建产品
  1.upto(10) do |i|
    sku_code = "SKU#{sprintf('%04d', i)}T"
    barcode  = "BAR#{sprintf('%04d', i)}T"
    next if Product.where(sku_code: sku_code).any?
    name = 'seed data'
    foreign_name = 'seed造数据'
    brand = 'seed'
    weight = 1.0
    price = 2.33
    p = account.products.create!(sku_code: sku_code,barcode: barcode, name: name, foreign_name: foreign_name, channel: channel.name)
    psp = ProductSalesProperty.create!(brand: brand, weight:weight, price: price)
    p.product_sales_property = psp
    p.save!
  end

end unless Padrino.env == :production



