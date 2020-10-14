# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_shelves', :map => 'api/v1.0/shelves' do

  before do
    load_api_request_params
  end

  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      filters.merge!({depot: { account_id: current_account.id }})

      query = Shelf.query_filter(filters)
      count = query.count
      @shelves = query.order(:depot_code => :asc, :area_code => :asc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @shelves.map(&:to_api), page: page, per_page: per_page, count: count }.to_json
    end
  end

  post :create, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_shelf_create_params

      @shelf = Shelf.new(shelf_params_create)
      @shelf.save ?
        { status: 'succ', data: @shelf.to_api }.to_json :
        { status: 'fail', reason: @shelf.errors.full_messages }.to_json
    end
  end

  post :batch_create, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_array('resource')

      data = []
      ActiveRecord::Base.transaction do
        @request_params['resource'].each_with_index do |resource, index|
          begin
            validate_depot_and_depot_area(resource['depot_id'], resource['depot_area_id'])
            new_shelf = Shelf.create!(resource)
            data << new_shelf.to_api
          rescue
            raise t('api.errors.batch_create_error', :index => index)
          end
        end
      end
      { status: 'succ', data: data }.to_json
    end
  end

  post :validate, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_shelf_create_params

      @shelf = Shelf.new(shelf_params_create)
      @shelf.validate ?
        { status: 'succ' }.to_json :
        { status: 'fail', reason: @shelf.errors.full_messages }.to_json
    end
  end

  put :update, :map => ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_shelf

      @shelf.update(shelf_params_update) ?
        { status: 'succ', data: @shelf.to_api }.to_json :
        { status: 'fail', reason: @shelf.errors.full_messages }.to_json
    end
  end

  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_shelf

      if @shelf.can_delete?
        @shelf.destroy ?
          { status: 'succ'}.to_json:
          { status: 'fail', reason: @shelf.errors.full_messages }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'Shelf', :id => params[:id])
      end
    end
  end

  get :shelf_infos, :map => ':id/shelf_infos', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_shelf

      { status: 'succ', data: @shelf.shelf_infos.map(&:to_api) }.to_json
    end
  end

end