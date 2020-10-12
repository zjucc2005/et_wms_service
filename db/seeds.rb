
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
if Account.find_by_email('lifuyuan@lifuyuan.com').nil?
  Account.create(
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


