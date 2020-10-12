# encoding: utf-8
class AuthorizationCode < ActiveRecord::Base
  include Oauth2Token
  self.default_lifetime = 10.minutes

  def access_token
    @access_token ||= expired! && account.access_tokens.create(:client => client)
  end

end
