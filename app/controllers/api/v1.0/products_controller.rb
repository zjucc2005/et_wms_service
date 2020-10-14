# encoding: utf-8
EtWmsService::App.controllers :"#{'api_v1.0_products'}", :map => '/api/v1.0/products' do

  before do
    load_api_request_params
  end

  # Preparation - functions to accomplish
  # 1. ServiceCategory search(list, detail(parent, children))
  # 2. ProductCategory search(list, detail(parent, children))

  # 3. Product search(:sales_property => true/false)
  # 4. Product get(:sales_property => true/false)
  # 5. Product create(validate params)
  # 6. Product update(validate params)
  # 6.1 only part of attributes can be updated
  # 6.2 provide several api for update different attributes?
  # 7. Product delete

  #创建新product
  post :create, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @message = []
      ActiveRecord::Base.transaction do
        product = current_account.products.new(product_params_create)
        product.channel ||= current_account.channels[0].name
        if @request_params['create_psp']
          psp = ProductSalesProperty.new(product_sales_property_params_create)
          if @request_params['thumbnail_name'].present?
            dir_path = "uploads/tmp/#{Time.now.strftime("%Y%m%d")}"
            FileUtils.mkdir_p dir_path unless Dir.exist? dir_path
            file_path = "#{dir_path}/#{@request_params['thumbnail_name']}"
            File.delete(file_path) if File.exist?(file_path)
            File.open(file_path,"wb+") do |f|
              f.write(Base64.decode64(@request_params['thumbnail']))
              psp.thumbnail = f
              File.delete(f)
            end
          end
          @message += psp.errors.full_messages unless psp.save
          product.product_sales_property = psp
        end
        @message += product.errors.full_messages unless product.save
      end

      @ret_data = @message.present? ? { status: 'fail', reason: @message } : { status: 'succ'}
      @ret_data.to_json
    end
  end

  post :import_new, :provides => [:json] do
    ActiveRecord::Base.transaction do
      api_rescue do
        authenticate_access_token
        check_product_import_hash
      end
      raise ActiveRecord::Rollback,"rollback!" unless @importstatus
    end
    @ret_data.to_json
  end

  #product列表
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page      = params['page']     || @request_params['page']     || 1
      per_page  = params['per_page'] || @request_params['per_page'] || 10
      filters   = params['q']        || @request_params['q']        || {}
      #默认不分级查询 ; params[:class_flag]=='yes' 分级
      class_flag = params[:class_flag]
      if class_flag == 'yes'
        p_cat = ProductCategory.where(id: filters['product_category']).first
        if p_cat
          filters.delete('product_category')
          filters['product_category_id_in'] = p_cat.recursive_subset
        end
        s_cat = ServiceCategory.where(id: filters['service_category']).first
        if s_cat
          filters.delete('service_category').first
          filters['service_category_id_in'] = s_cat.recursive_subset
        end
      end

      query     = Product.query_filter(filters.merge(query_privilege))
      @count    = query.count
      @products = query.order(:created_at => :asc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @products.map(&:to_api), page: page, per_page: per_page, count: @count }.to_json
    end
  end

  #product单个信息
  get :show, :map=>':id/show', :provides=> [:json] do
    api_rescue do
      authenticate_access_token
      load_product
      { status: 'succ', data: @product.to_api_show }.to_json
    end
  end

  #更新product
  put :update, :map => ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_product

      ActiveRecord::Base.transaction do
        @product.update!(product_params_update)
        if @product.product_sales_property
          @product.product_sales_property.update!(product_sales_property_params_update)
          if @request_params['thumbnail_name'].present?
            dir_path = "uploads/tmp/#{Time.now.strftime("%Y%m%d")}"
            FileUtils.mkdir_p dir_path unless Dir.exist? dir_path
            file_path = "#{dir_path}/#{@request_params['thumbnail_name']}"
            File.delete(file_path) if File.exist?(file_path)
            File.open(file_path,"wb+") do |f|
              f.write(Base64.decode64(@request_params['thumbnail']))
              @product.product_sales_property.update!(thumbnail: f)
              File.delete(f)
            end
          end
        end
      end
      { status: 'succ'}.to_json
    end
  end

  #删除product
  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_product
      if @product.can_delete?
        @product.destroy!
        { status: 'succ' }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'Product', :id => @product.id)
      end
    end
  end

  # 估计要弃用
  #查询单个商品
  get :search , :provides=> [:json] do
    api_rescue do
      @product = Product.query_filter(product_search_params).last
      if @product
        { status: 'succ', data: @product.to_api_search }.to_json
      else
        raise 'Product not found'
      end
    end
  end
end