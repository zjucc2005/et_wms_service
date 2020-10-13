# encoding: utf-8
EtWmsService::App.controllers :"#{'api_v1.0_service_categories'}", :map => '/api/v1.0/service_categories' do

  before do
    load_api_request_params
  end

  get :index, :provides => [:json] do
    api_rescue do
      page     = params[:page] || 1
      per_page = params[:per_page] || 10
      filters  = params[:q] || {}
      offset   = (page.to_i - 1) * per_page.to_i

      @service_categories = ServiceCategory.query_filter(filters).offset(offset).limit(per_page).order(:created_at => :asc)
      { status: 'succ', data: @service_categories.map(&:serializable_hash) }.to_json
    end
  end

  # ServiceCategory 分级查询
  # 参数 - optional: :parent_id
  get :search, :provides => [:json] do
    api_rescue do
      @service_categories = ServiceCategory.where(parent_id: nil)
      { status: 'succ', data: @service_categories.map(&:to_api) }.to_json
    end
  end

  get :search, :with => :parent_id, :provides => [:json] do
    api_rescue do
      @service_categories = ServiceCategory.where(parent_id: params[:parent_id])
      { status: 'succ', data: @service_categories.map(&:to_api) }.to_json
    end
  end

  # ServiceCategory 单例查询
  # 参数 - required: :id
  get :show, :map=> ':id/show', :provides => [:json] do
    api_rescue do
      @service_category = ServiceCategory.find(params[:id])
      { status: 'succ', data: @service_category.to_api }.to_json
    end
  end
end