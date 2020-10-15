# encoding: utf-8
module EtWmsService
  class App
    module OutboundHelper

      def load_outbound_notification
        @outbound_notification = OutboundNotification.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'OutboundNotification', :id => params[:id]) if @outbound_notification.nil?
        validate_load_privilege(@outbound_notification)
      end

      def load_outbound_order
        @outbound_order = OutboundOrder.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'OutboundOrder', :id => params[:id]) if @outbound_order.nil?
        validate_load_privilege(@outbound_order.outbound_notification)
      end
      alias :reload_outbound_order :load_outbound_order

      def load_outbound_order_by_batch_num
        @outbound_order = OutboundOrder.find_by(batch_num: @request_params['batch_num'])
        raise t('api.errors.not_found_batch_num', :model => 'OutboundOrder', :batch_num => @request_params['batch_num']) if @outbound_order.nil?
        validate_load_privilege(@outbound_order.outbound_notification)
      end

      def validate_shpmt_product(shpmt_product)
        unless %w[DHL DHL经济包 CZ-EMS DPD].include?(shpmt_product)
          raise t('api.errors.outbound_orders.invalid_shipment_product', :product => shpmt_product)
        end
      end

      def validate_shpmt_addr_info(shpmt_addr_info)
        shpmt_addr_info['sender'] ||= {}
        %w[sender recipient].each do |field|
          raise I18n.t('api.errors.blank', :field => "shpmt_addr_info.#{field}") if shpmt_addr_info[field].nil?
          raise I18n.t('api.errors.not_hash', :field => "shpmt_addr_info.#{field}") unless Hash === shpmt_addr_info[field]
        end
        # %w[city name email street country postcode telephone houseNumber].each do |sub_field|
        #   raise I18n.t('api.errors.blank', :field => "shpmt_addr_info.sender.#{sub_field}") if shpmt_addr_info['sender'][sub_field].blank?
        # end
        %w[city name street country postcode streetNumber].each do |sub_field|
          raise I18n.t('api.errors.blank', :field => "shpmt_addr_info.recipient.#{sub_field}") if shpmt_addr_info['recipient'][sub_field].blank?
        end
      end

      def validate_uniqueness_of_order_num(order_num)
        if OutboundOrder.where.not(status: 'cancelled').where(order_num: order_num).any?
          raise I18n.t('api.errors.outbound_orders.order_num_existed', :order_num => order_num)
        end
      end

      # 同一订单中的sku不能重复
      def validate_uniqueness_of_outbound_skus(outbound_skus)
        sku_count = outbound_skus.length
        uniq_sku_count = outbound_skus.map{|outbound_sku| outbound_sku['sku_code'] }.uniq.length
        raise 'duplicated sku' if uniq_sku_count < sku_count
      end

      def outbound_skus_construct(outbound_order, outbound_skus=[])
        raise 'outbound_skus cannot be blank' unless outbound_skus.present?
        raise 'outbound_skus must be Array'   unless Array === outbound_skus
        validate_uniqueness_of_outbound_skus(outbound_skus)
        outbound_skus.each do |outbound_sku|
          next if outbound_sku['quantity'].to_i == 0  # 忽略出库数量为0的sku, 修复调用时多出一条空sku信息的bug
          account = Account.where(email: outbound_sku['sku_owner'].try(:strip)).first || current_account
          inventory = account.inventories.where(sku_code: outbound_sku['sku_code'].strip, barcode: outbound_sku['barcode'].strip).first
          raise "#{outbound_sku['sku_code']} 库存不足" if inventory.nil?
          # 库存总量 >= 当前预报数量 + 已预报数量(未取货下架)
          if inventory.quantity >= outbound_sku['quantity'] + OutboundSku.unpicked_quantity_sum(outbound_sku['sku_code'], outbound_sku['barcode'], account.id)
            outbound_order.outbound_skus.create!(
              sku_code:     outbound_sku['sku_code'].strip,
              barcode:      outbound_sku['barcode'].strip,
              account_id:   account.id,
              quantity:     outbound_sku['quantity'],
              name:         inventory.name,
              foreign_name: inventory.foreign_name,
            )
          else
            raise "#{outbound_sku['sku_code']} 库存不足"
          end
        end
      end

      # 修改订单 - 采用先取消, 再新建(前后订单号相同), 保留历史订单记录
      def update_outbound_skus(outbound_order, outbound_skus=[])
        new_outbound_order = outbound_order.outbound_notification.outbound_orders.create!(
          order_num:       outbound_order.order_num,
          depot_code:      outbound_order.depot_code,
          outbound_method: outbound_order.outbound_method.present? ? 'picking' : nil,
          shpmt_num:       outbound_order.shpmt_num,
          shpmt_product:   outbound_order.shpmt_product,
          shpmt_addr_info: outbound_order.shpmt_addr_info,
        )
        outbound_skus_construct(new_outbound_order, outbound_skus)
        outbound_order.cancel!
        new_outbound_order  # return
      end

    end
    helpers OutboundHelper
  end
end
