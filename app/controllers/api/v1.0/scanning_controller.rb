EtWmsService::App.controllers :'api_v1.0_scanning', :map => 'api/v1.0/scanning' do

  before do
    load_api_request_params
  end

  # 2.3.1 扫描流水号创建Mypost4u包裹
  post :create_mypost4u_parcel , :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_order_by_batch_num
      raise I18n.t('api.errors.invalid_operation') unless @outbound_order.can_print?
      validate_presence('weight')
      validate_presence('length')
      validate_presence('width')
      validate_presence('height')
      @request_params['weight'] = Float(@request_params['weight'])
      @request_params['length'] = Float(@request_params['length'])
      @request_params['width']  = Float(@request_params['width'])
      @request_params['height'] = Float(@request_params['height'])

      # posting_path, shipment_path = @outbound_order.mp4_file_path
      # if @outbound_order.parcel_num.nil?
      #   parcel_params = transfer_parcel_params(@outbound_order)
      #   logger.info "parcel_params: #{parcel_params}"
      #   mp4_parcels_transport(parcel_params, @outbound_order)
      # end
      # { status: 'succ', posting_url: "#{request.base_url}#{posting_path}", shipment_url: "#{request.base_url}#{shipment_path}" }.to_json
      @outbound_order.update!(
        status: 'printed',
        printed_at: Time.now,
        weight: @request_params['weight'],
        length: @request_params['length'],
        width:  @request_params['width'],
        height: @request_params['height']
      )
      { status: 'succ', posting_url: nil, shipment_url: nil }.to_json
    end
  end

end