# encoding: utf-8
module SecureToken

  # Generate a string randomly to be used as token.
  def self.generate(bytes = 64)
    SecureRandom.urlsafe_base64(bytes)
  end
end