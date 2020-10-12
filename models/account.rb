# encoding: utf-8
class Account < ActiveRecord::Base
    attr_accessor :password, :password_confirmation

    has_many :accounts_and_account_groups, :class_name => 'AccountAndAccountGroup', :dependent => :destroy
    has_many :account_groups, :class_name => 'AccountGroup', :through => :accounts_and_account_groups, :source => :account_group
    has_many :accounts_and_roles, :class_name => 'AccountAndRole', :dependent => :destroy
    has_many :roles, :class_name => 'Role', :through => :accounts_and_roles, :source => :role
    has_many :accounts_and_channels, :class_name => 'AccountAndChannel', :dependent => :destroy
    has_many :channels, :class_name => 'Channel', :through => :accounts_and_channels, :source => :channel

    has_many :access_tokens, :class_name => 'AccessToken'
    has_many :refresh_tokens, :class_name => 'RefreshToken'
    has_many :authorization_codes, :class_name => 'AuthorizationCode'
    # has_many :clients, :class_name => 'Client'

    # Validations
    validates_presence_of   :email
    validates_length_of     :email, :within => 3..100
    validates_uniqueness_of :email, :case_sensitive => false
    validates_format_of     :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

    validates_presence_of     :password,                   :if => :password_required
    validates_presence_of     :password_confirmation,      :if => :password_required
    validates_length_of       :password, :within => 8..40, :if => :password_required
    validates_confirmation_of :password,                   :if => :password_required

    validates_presence_of   :nickname
    validates_length_of     :nickname, :within => 3..40
    validates_uniqueness_of :nickname, :case_sensitive => false
    validates_format_of     :nickname, :with => /\A[a-zA-Z]+[a-zA-Z\d_\.]*\Z/i  # initial character should be a letter

    scope :active, lambda{ where.not(:confirmed_at => nil) }

    # Callbacks
    before_save :encrypt_password, :if => :password_required

    extend QueryFilter

    # For authentication purpose
    def self.authenticate(email, password)
        if email.present?
            @account = Padrino.env == :test ?
              self.where('lower(email) = lower(?)', email.to_s.strip).first :
              self.active.where('lower(email) = lower(?)', email.to_s.strip).first
        end
        @account && @account.has_password?(password.to_s.strip) ? @account : nil
    end

    def has_password?(password)
        ::BCrypt::Password.new(password_digest) == password
    end

    # Examples:
    #     account.authenticated?(:confirmation,   'confirmation_token')
    #     account.authenticated?(:remember,       'remember_token')
    #     account.authenticated?(:reset_password, 'reset_password_token')
    def authenticated?(attribute, token)
        digest = self.try("#{attribute}_digest")
        return false if digest.nil?
        ::BCrypt::Password.new(digest) == token
    end

    # Generate a friendly string randomly to be used as token.
    # By default, length is 20 characters.
    def self.new_token(length = 20)
        rlength = (length * 3) / 4
        SecureToken.generate(rlength).tr('lIO0', 'sxyz')
        # SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
    end

    # Digest a specified string to be saved into database.
    def self.digest(string)
        cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
        value = ::BCrypt::Password.create(string, cost: cost)
        value.force_encoding(Encoding::UTF_8) if value.encoding == Encoding::ASCII_8BIT
    end

    def to_api
        {
          :id => id,
          :mp4_id => mp4_id,
          :email => email,
          :nickname => nickname,
          :telephone => telephone,
          :parent_id => parent_id,
          :created_at => created_at,
          :roles => all_roles.map(&:to_api_simple),
          :channels => channels.map(&:to_api),
          :account_groups => account_groups.map(&:to_api_simple)
        }.merge(personal_infos)
    end

    def personal_infos
        {
          firstname: firstname,
          lastname: lastname,
          sex: sex,
          country: country,
          city: city,
          address: address,
          company: company,
          qq_num: qq_num,
          wechat_num: wechat_num,
          extra_email: extra_email,
          memo: memo
        }
    end

    # return all roles related with self and self account_groups
    def all_roles
        _role_ids_ = (account_groups.map(&:role_ids) + role_ids).flatten.uniq
        Role.where(id: _role_ids_)
    end

    def super_admin?
      all_roles.pluck(:name).include?('super_admin')
    end

    def accessible_channels
      self_channels = channels.pluck(:name)
      self_channels.present? ? Channel.where('name ~ ?', "^#{self_channels.join('|')}.*") : channels
    end

    private
    def encrypt_password
        self.password_digest = Account.digest(password)
    end

    def password_required
        password_digest.blank? || password.present?
    end
end
