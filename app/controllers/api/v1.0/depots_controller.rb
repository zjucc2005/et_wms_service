# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_depots', :map => 'api/v1.0/depots' do

  before do
    load_api_request_params
  end

  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = Depot.query_filter(filters.merge(query_privilege))
      count = query.count
      @depots = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @depots.map(&:to_api), page: page, per_page: per_page, count: count }.to_json
    end
  end

  get :show, :map => ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_depot

      { status: 'succ', data: @depot.to_api }.to_json
    end
  end

  post :create, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @depot = current_account.depots.new(depot_params_create)
      @depot.channel = current_account.channels[0].name
      @depot.save ?
        { status: 'succ', data: @depot.to_api }.to_json :
        { status: 'fail', reason: @depot.errors.full_messages }.to_json
    end
  end

  put :update, :map => ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_depot

      @depot.update(depot_params_update) ?
        { status: 'succ', data: @depot.to_api }.to_json :
        { status: 'fail', reason: @depot.errors.full_messages }.to_json
    end
  end

  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_depot

      if @depot.can_delete?
        @depot.destroy ?
          { status: 'succ'}.to_json:
          { status: 'fail', reason: @depot.errors.full_messages }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'Depot', :id => params[:id])
      end
    end
  end

  post :create_depot_areas, :map => ':id/create_depot_areas', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_depot

      reasons = []
      area_codes = (params[:area_codes] || @request_params['area_codes']).uniq
      area_codes.each do |area_code|
        if @depot.depot_areas.where(area_code: area_code).count > 0
          reasons << t('api.errors.depot.area_code_taken', :area_code => area_code)
        end
      end

      if reasons.any?
        { status: 'fail', reason: reasons }.to_json
      else
        area_codes.each { |area_code| @depot.depot_areas.create(area_code: area_code) }
        @depot_areas = @depot.depot_areas.where(area_code: area_codes)
        { status: 'succ', data: @depot_areas.map(&:to_api) }.to_json
      end
    end
  end

end