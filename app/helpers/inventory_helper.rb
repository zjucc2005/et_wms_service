# encoding: utf-8
module EtWmsService
  class App
    module InventoryHelper

      def load_inventory
        @inventory = Inventory.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'Inventory', :id => params[:id]) if @inventory.nil?
        validate_load_privilege(@inventory)
      end

      def load_inventory_info
        @inventory_info = InventoryInfo.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'InventoryInfo', :id => params[:id]) if @inventory_info.nil?
        validate_load_privilege(@inventory_info.inventory)
      end

      def load_inventory_operation_log
        @inventory_operation_log = InventoryOperationLog.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'InventoryOperationLog', :id => params[:id]) if @inventory_operation_log.nil?
        validate_load_privilege(@inventory_operation_log)
      end

      def load_inventory_task
        @inventory_task = InventoryTask.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'InventoryTask', :id => params[:id]) if @inventory_task.nil?
        unless @inventory_task.operator_ids.include?(current_account.id)
          validate_load_privilege(@inventory_task)
        end
      end

      def inventory_caution_threshold
        resource_params_permit(%w[caution_threshold])
      end

      def inventory_settings_params
        resource_params_permit(InventorySetting::FIELD_ATTRIBUTES.keys)
      end

      def validate_create_transfer_task_params
        validate_array('transfer_infos')
        %w[scheduled_time to_depot_code].each do |field|
          raise t('api.errors.blank', :field => field) if @request_params[field].blank?
        end
      end

    end
    helpers InventoryHelper
  end
end
