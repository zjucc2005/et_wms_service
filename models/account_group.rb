class AccountGroup < ActiveRecord::Base
    has_many :accounts_and_account_groups, :class_name => 'AccountAndAccountGroup', :dependent => :destroy
    has_many :accounts, :class_name => 'Account', :through => :accounts_and_account_groups, :source => :account
    has_many :account_groups_and_roles, :class_name => 'AccountGroupAndRole', :dependent => :destroy
    has_many :roles, :class_name => 'Role', :through => :account_groups_and_roles, :source => :role

    validates_presence_of :name
    validates_uniqueness_of :name, :case_sensitive => false

    extend QueryFilter

    #获取该用户组中所有用户成员(email)
    def get_account_list
        accounts.pluck(:email)
    end

    #获取该用户组中所有用户角色(name)
    def get_role_list
        role_list=[]
        if agrs=AccountGroupAndRole.where(account_group_id: self.id)
            if rss=Role.where(id: agrs.map{|agr|agr.role_id})
                rss.each do |rs|
                    hash=Hash.new
                    hash["id"]=rs.id
                    hash["application_id"]=rs.application_id
                    role_list<<hash
                end
            end
        end
        role_list
    end

    def can_delete?
        accounts.blank? && roles.blank?
    end

  def to_api
      { id: id, name: name, roles: roles.map(&:to_api), can_delete: can_delete? }
  end

  def to_api_simple
      { id: id, name: name }
  end

end
