# encoding: utf-8
class Settings < Settingslogic
  source Padrino.root('config/settings.yml')
  namespace "#{Padrino.env}"
end