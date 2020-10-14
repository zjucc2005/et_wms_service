# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inventory_settings', :map => 'api/v1.0/inventory_settings' do

  before do
    load_api_request_params
  end

  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      { status: 'succ', data: InventorySetting.personal_settings(current_account.id) }.to_json
    end
  end

  # Request params:
  # {
  #   :global_caution_threshold => 123
  # }
  put :update_global_caution_threshold, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @inventory_setting = InventorySetting.global_caution_threshold.find_or_initialize_by(account_id: current_account.id)
      @inventory_setting.update(field_value: params[:global_caution_threshold] || @request_params['global_caution_threshold']) ?
        { status: 'succ' }.to_json :
        { status: 'fail', reason: @inventory_setting.errors.full_messages }.to_json
    end
  end

  # Update all settings via this api
  # Request params:
  # {
  #   :global_caution_threshold       => 123,
  #   :periodic_check_task_switch     => 'on',
  #   :check_task_generation_interval => 7,
  #   :check_frequency_yearly_default => 52,
  #   :check_frequency_yearly_cat_a   => 52,
  #   :check_frequency_yearly_cat_b   => 52,
  #   :check_frequency_yearly_cat_c   => 52,
  #   ...
  # }
  put :update, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      ActiveRecord::Base.transaction do
        inventory_settings_params.each do |field_key, field_value|
          begin
            inventory_setting = current_account.inventory_settings.find_or_initialize_by(field_key: field_key)
            inventory_setting.update!(field_value: field_value)
          rescue
            raise t('api.errors.invalid_params', :name => field_key)
          end
        end
      end

      { status: 'succ', data: InventorySetting.personal_settings(current_account.id) }.to_json
    end
  end

end