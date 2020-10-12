# encoding: utf-8
class RefreshToken < ActiveRecord::Base
  include Oauth2Token
  self.default_lifetime = 1.month
  has_many :access_tokens, :class_name => 'AccessToken'
end
