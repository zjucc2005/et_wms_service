# encoding: utf-8
module EtWmsService
  class App
    module ProductHelper

      def product_params_create
        resource_params_permit(%w[sku_code barcode name foreign_name product_category_id service_category_id description])
      end

      def product_params_update
        resource_params_permit(%w[sku_code barcode name foreign_name description product_category_id])
      end

      def product_sales_property_params_create
        resource_params_permit(%w[brand model price currency weight clearance_attributes])
      end

      def product_sales_property_params_update
        resource_params_permit(%w[brand model price currency weight clearance_attributes])
      end

      def product_search_params
        resource_params_permit(%w[sku_code barcode name])
      end

      def load_product
        @product = Product.find_by(id: params[:id])
        raise "Product with id #{params[:id]} not found" if @product.nil?
      end

      def check_product_import_hash
        dir_path = "uploads/tmp/#{Time.now.strftime("%Y%m%d")}"
        FileUtils.mkdir_p dir_path unless Dir.exist? dir_path
        import_msg = Hash.new
        @importstatus = true
        @request_params.each do |row,product|
          if product.is_a?(Hash)
            product_hash = Hash.new
            product_sales_property_hash = Hash.new
            reasons = []
            %w(sku_code barcode name foreign_name description sku_owner).each do |i|
              product_hash[i] = product[i]
            end
            product_hash['channel'] = current_account.channels[0].name
            if product["product_category_id"].present?
              product_category = ProductCategory.where(name:product["product_category_id"]).last
              if product_category
                product_hash["product_category_id"] = product_category.id
              else
                reasons << "can not find product category"
              end
            end
            if product["service_category_id"].present?
              service_category = ServiceCategory.where(name:product["service_category_id"]).last
              if service_category
                product_hash["service_category_id"] = service_category.id
              else
                reasons << "can not find service category"
              end
            end
            pd = current_account.products.new(product_hash)
            if product["create_psp"] == "yes"
              %w(brand model price currency weight clearance_attributes).each do |i|
                product_sales_property_hash[i] = product[i]
              end
              psp = ProductSalesProperty.new(product_sales_property_hash)
              if product['thumbnail_name'].present?
                File.open("#{dir_path}/#{product['thumbnail_name']}","wb+") do |f|
                  string = Base64.decode64(product['thumbnail'])
                  f.write(string)
                  psp.thumbnail = f
                  File.delete(f)
                end
              end
              unless psp.save
                reasons += psp.errors.full_messages
              else
                pd.product_sales_property = psp
              end
            end
            reasons += pd.errors.full_messages unless pd.save
            import_msg[row] = reasons if reasons.present?
          end
        end
        if import_msg.count > 0
          @importstatus = false
          @ret_data = { status: 'fail', reason: import_msg }
        else
          @ret_data = { status: 'succ' }
        end
      end

    end
    helpers ProductHelper
  end
end
