# encoding: utf-8
EtWmsService::App.controllers :"#{'api_v1.0_product_categories'}", :map => '/api/v1.0/product_categories' do

  before do
    load_api_request_params
  end

  get :index, :provides => [:json] do
    api_rescue do
      filters  = params[:q] || {}
      @product_categories = ProductCategory.query_filter(filters).order(:created_at => :asc)
      { status: 'succ', data: @product_categories.map(&:serializable_hash) }.to_json
    end
  end

  # ProductCategory 分级查询
  # 参数 - optional: :parent_id
  get :search, :provides => [:json] do
    api_rescue do
      @product_categories = ProductCategory.where(parent_id: nil)
      { status: 'succ', data: @product_categories.map(&:to_api) }.to_json
    end
  end

  get :search, :with => :parent_id, :provides => [:json] do
    api_rescue do
      @product_categories = ProductCategory.where(parent_id: params[:parent_id])
      { status: 'succ', data: @product_categories.map(&:to_api) }.to_json
    end
  end

  # ProductCategory 单例查询
  # 参数 - required: :id
  get :show,  :map=> ':id/show', :provides => [:json] do
    api_rescue do
      @product_category = ProductCategory.find(params[:id])
      { status: 'succ', data: @product_category.to_api }.to_json
    end
  end

end