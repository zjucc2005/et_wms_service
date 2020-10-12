# encoding: utf-8
# EtWmsService::App.mailer :account do
#   email :confirmation do |email, confirmation_url|
#     from 'info@quaie.com'
#     to email
#     subject 'Welcome to the site!'
#     locals :confirmation_url => confirmation_url
#     render 'account/confirmation'
#     content_type :html
#     via :sendmail, :location => '/usr/bin/sendmail'
#   end
#
#   email :reset_password do |email, reset_password_url|
#     from 'info@quaie.com'
#     to email
#     subject 'Reset Password!'
#     locals :reset_password_url => reset_password_url
#     render 'account/reset_password'
#     content_type :html
#     via :sendmail, :location => '/usr/bin/sendmail'
#   end
# end