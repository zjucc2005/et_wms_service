# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inbound_received_infos', :map => 'api/v1.0/inbound_received_infos' do
  before do
    load_api_request_params
  end

  # 2.1.17 收货信息删除 ADMIN
  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_received_info

      if @inbound_received_info.can_delete?
        @inbound_received_info.destroy!
        { status: 'succ' }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'InboundReceivedInfo', :id => params[:id])
      end
    end
  end
end