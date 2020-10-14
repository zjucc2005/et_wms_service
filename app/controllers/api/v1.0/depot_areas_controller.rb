# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_depot_areas', :map => 'api/v1.0/depot_areas' do

  before do
    load_api_request_params
  end

  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_depot_area

      if @depot_area.can_delete?
        @depot_area.destroy ?
          { status: 'succ' }.to_json:
          { status: 'fail', reason: @depot_area.errors.full_messages }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'DepotArea', :id => params[:id])
      end
    end
  end

end