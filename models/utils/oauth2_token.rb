# encoding: utf-8
module Oauth2Token
  # Shared methods for Oauth2.0 tokens model: AccessToken, RefreshToken, AuthorizationCode
  # include Oauth2Token allows you to use these following methods as instance methods

  def self.included(klass)
    klass.class_eval do
      cattr_accessor :default_lifetime
      self.default_lifetime = 1.minute
      belongs_to :account, :class_name => 'Account'
      belongs_to :client,  :class_name => 'Client'

      before_validation :setup, :on => :create
      validates_presence_of :client, :expires_at, :token
      validates_uniqueness_of :token

      scope :valid, lambda { where('expires_at >= ?', Time.now.utc) }
    end
  end

  def expires_in
    (expires_at - Time.now.utc).to_i
  end

  def expired!
    self.expires_at = Time.now.utc
    self.save!
  end

  private
  def setup
    self.token = SecureToken.generate
    self.expires_at ||= self.default_lifetime.from_now
  end
end