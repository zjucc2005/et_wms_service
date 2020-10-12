# encoding: utf-8
class Client < ActiveRecord::Base
  has_many :access_tokens, :class_name => 'AccessToken', :dependent => :destroy
  has_many :refresh_tokens, :class_name => 'RefreshToken', :dependent => :destroy
  has_many :authorization_codes, :class_name => 'AuthorizationCode', :dependent => :destroy
  # belongs_to :account, :class_name => 'Account'

  before_validation :setup, :on => :create
  validates_presence_of :identifier, :secret, :name #, :website, :redirect_uri
  validates_uniqueness_of :identifier

  private
  def setup
    self.identifier ||= SecureToken.generate(16)
    self.secret     ||= SecureToken.generate
  end

end
