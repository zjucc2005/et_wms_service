# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inbound_skus', :map => 'api/v1.0/inbound_skus' do
  before do
    load_api_request_params
  end

  # 2.1.12 入库预报sku修改 CLIENT & ADMIN
  post :update, :map => ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_sku

      if @inbound_sku.can_update?
        @inbound_sku.update(inbound_sku_params_update) ?
          { status: 'succ', data: @inbound_sku.to_api }.to_json :
          { status: 'fail', reason: @inbound_sku.errors.full_messages }.to_json
      else
        raise t('api.errors.cannot_update', :model => 'InboundSku', :id => params[:id])
      end
    end
  end

  # 2.1.13 入库预报sku删除 CLIENT & ADMIN
  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_sku

      if @inbound_sku.can_delete?
        @inbound_sku.destroy ?
          { status: 'succ' }.to_json :
          { status: 'fail', reason: @inbound_sku.errors.full_messages }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'InboundSku', :id => params[:id])
      end
    end
  end

end