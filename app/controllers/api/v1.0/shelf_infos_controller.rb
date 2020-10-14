# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_shelf_infos', :map => 'api/v1.0/shelf_infos' do

  before do
    load_api_request_params
  end

  put :update, :map => ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_shelf_info

      @shelf_info.update(shelf_info_params_update) ?
        { status: 'succ', data: @shelf_info.to_api }.to_json :
        { status: 'fail', reason: @shelf_info.errors.full_messages }.to_json
    end
  end

end