# encoding: utf-8
module EtWmsService
  class App
    module InboundHelper

      def inbound_notification_params_create
        resource_params_permit(%w[inbound_depot_code scheduled_time transport_method transport_memo parcel_quantity])
      end

      def inbound_sku_params_create
        resource_params_permit(%w[sku_code barcode sku_owner quantity production_date expiry_date country_of_origin abc_category])
      end

      def inbound_sku_params_update
        resource_params_permit(%w[quantity])
      end

      def load_inbound_notification
        @inbound_notification = InboundNotification.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'InboundNotification', :id => params[:id]) if @inbound_notification.nil?
        validate_load_privilege(@inbound_notification)
      end

      def load_inbound_batch
        @inbound_batch = InboundBatch.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'InboundBatch', :id => params[:id]) if @inbound_batch.nil?
        unless @inbound_batch.operator_ids.include?(current_account.id)
          validate_load_privilege(@inbound_batch.inbound_notification)
        end
      end

      def load_inbound_sku
        @inbound_sku = InboundSku.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'InboundSku', :id => params[:id]) if @inbound_sku.nil?
        validate_load_privilege(@inbound_sku.inbound_notification)
      end

      def load_inbound_received_info
        @inbound_received_info = InboundReceivedInfo.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'InboundReceivedInfo', :id => params[:id]) if @inbound_received_info.nil?
        validate_load_privilege(@inbound_received_info.inbound_notification)
      end

      def load_inbound_batches_operate_params
        validate_hash('inbound_batch_sku')
        %w[barcode quantity shelf_num].each do |field|
          if @request_params['inbound_batch_sku'][field].blank?
            raise t('api.errors.blank', :field => "inbound_batch_sku.#{field}")
          end
        end

        %w[barcode quantity shelf_num operate_memo].each do |field|
          field == 'quantity' ?
            instance_variable_set("@#{field}", Integer(@request_params['inbound_batch_sku'][field])) :
            instance_variable_set("@#{field}", @request_params['inbound_batch_sku'][field])
        end
      end

      def load_inbound_batches_register_problem_params
        validate_hash('inbound_batch_sku')
        %w[barcode quantity problem_type].each do |field|
          if @request_params['inbound_batch_sku'][field].blank?
            raise t('api.errors.blank', :field => "inbound_batch_sku.#{field}")
          end
        end

        %w[barcode quantity problem_type problem_memo production_date expiry_date country_of_origin abc_category].each do |field|
          field == 'quantity' ?
            instance_variable_set("@#{field}", Integer(@request_params['inbound_batch_sku'][field])) :
            instance_variable_set("@#{field}", @request_params['inbound_batch_sku'][field])
        end
      end

      def validate_inbound_notifications_create_params
        validate_array('inbound_skus')
        %w[inbound_depot_code scheduled_time].each do |field|
          validate_presence(field)
        end
      end

      # def validate_inbound_notifications_create_transfer_params
      #   validate_array('inbound_skus')
      #   %w[inbound_depot_code scheduled_time task_num].each do |field|
      #     validate_presence(field)
      #   end
      # end

    end
    helpers InboundHelper
  end
end
