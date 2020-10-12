# encoding: utf-8
module QueryFilter

  # 2018-10-15, add argument 'column_type' to :filter_rules
  # 2018-11-12, add filter rule 'auth' to authenticate channel
  Version = '1.3'
  def self.version; Version; end

  # Extend module QueryFilter in your specified class, such as Account, allows you to use
  # these following methods as class methods.
  #
  # class Account < ActiveRecord::Base
  #     extend QueryFilter
  # end
  # <OR>
  # Account.extend QueryFilter
  #
  # == Filter method for ActiveRecord::Base model
  #
  # Example:
  #
  #     Account.filter({ 'email_cont' => 'admin', 'nickname_in' => ['admin', 'test'] })
  #     works as the same as
  #     Account.where('email LIKE ?', '%admin%').where(nickname: ['admin', 'test'])
  #
  # Filter Rules:
  #
  #     :matcher     :rule               :query_syntax
  #     name      => equal            => 'name = ?'
  #     name_eq   => equal            => 'name = ?'
  #     name_in   => in               => 'name in (?)'
  #     name_cont => contain(:string) => 'name like ?'
  #     name_cont => contain(:json)   => 'name @> ?'
  #     name_gt   => greater than     => 'name > ?'
  #     name_gteq => greater/equal    => 'name >= ?'
  #     name_lt   => less than        => 'name < ?'
  #     name_lteq => less/equal       => 'name <= ?'
  #     name_auth => start with word(s) in list
  #
  # == If current table has associations with other tables, such as
  #
  #     class Account < ActiveRecord::Base
  #       has_many :roles, :class_name => "Role"
  #       has_one :account_info, :class_name => "AccountInfo"
  #     end
  #
  # fields of roles/account_info can also be provided in filters, and filter's form is a nested hash.
  # NOTE: 1. plural/singular is strict;
  #       2. hash's keys can be both String or Symbol;
  #
  #     {
  #       'email_cont' => 'admin', 'nickname' => 'admin',
  #       'roles' => { 'name' => 'admin' },
  #       'account_info' => { 'balance_gt' => 100 }
  #     }
  #
  def query_filter(filters={})
    raise NotImplementedError, 'uninitialized constant ActiveRecord::Base' unless defined?(ActiveRecord::Base)
    raise NotImplementedError, "#{self.to_s} is not a subclass of ActiveRecord::Base" unless self.superclass == ActiveRecord::Base

    matcher_regex = /^.+_(eq|in|cont|gt|gteq|lt|lteq|auth)$/
    query = self.all
    filters.stringify_keys!.each do |field_name, field_value|
      if field_name.match(matcher_regex)
        matcher      = field_name.split(matcher_regex)[-1]
        _field_name_ = field_name.split("_#{matcher}")[0]
        next unless self.column_names.include?(_field_name_)
        column_type = self.columns.find{|col| col.name == _field_name_}.type
        query = filter_rules(query, "#{self.table_name}.#{_field_name_}", field_value, column_type, matcher)
      else
        if self.column_names.include?(field_name)
          column_type = self.columns.find{|col| col.name == field_name}.type
          query = filter_rules(query, "#{self.table_name}.#{field_name}", field_value, column_type)
        else
          if field_value.is_a?(Hash) && field_value.present? && self._reflections.has_key?("#{field_name}")
            query = query.joins(:"#{field_name}")
            klass = self._reflections.fetch("#{field_name}").klass
            field_value.stringify_keys!.each do |nested_field_name, nested_field_value|
              if nested_field_name.match(matcher_regex)
                matcher = nested_field_name.split(matcher_regex)[-1]
                _nested_field_name_ = nested_field_name.split("_#{matcher}")[0]
              else
                matcher = 'eq'
                _nested_field_name_ = nested_field_name
              end
              next unless klass.column_names.include?(_nested_field_name_)
              column_type = klass.columns.find{|col| col.name == _nested_field_name_}.type
              query = filter_rules(query, "#{klass.table_name}.#{_nested_field_name_}", nested_field_value, column_type, matcher)
            end
          else
            next
          end
        end
      end
    end
    query
  end

  private
  def filter_rules(query, field_name, field_value, column_type=nil, matcher='eq')
    case matcher
      when 'eq'   then query.where(:"#{field_name}" => field_value)
      when 'in'   then query.where("#{field_name} in (?)", field_value)
      when 'cont'
        [:jsonb, :json].include?(column_type) ?
          query.where("#{field_name} @> ?", field_value.to_json) :
          query.where("#{field_name} LIKE ?", "%#{field_value}%")
      when 'gt'   then query.where("#{field_name} > ?", field_value)
      when 'gteq' then query.where("#{field_name} >= ?", field_value)
      when 'lt'   then query.where("#{field_name} < ?", field_value)
      when 'lteq' then query.where("#{field_name} <= ?", field_value)
      when 'auth'
        field_value = [field_value] if String === field_value
        query.where("#{field_name} ~ ?", "^(#{field_value.join('|')}).*")
      else query.where('1=0')
    end
  end
end