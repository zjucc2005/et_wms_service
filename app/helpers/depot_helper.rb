# encoding: utf-8
module EtWmsService
  class App
    module DepotHelper

      def load_depot
        @depot = Depot.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'Depot', :id => params[:id]) if @depot.nil?
        validate_load_privilege(@depot)
      end

      def load_depot_area
        @depot_area = DepotArea.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'DepotArea', :id => params[:id]) if @depot_area.nil?
        validate_load_privilege(@depot_area.depot)
      end

      def load_shelf
        @shelf = Shelf.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'Shelf', :id => params[:id]) if @shelf.nil?
        validate_load_privilege(@shelf.depot)
      end

      def load_shelf_info
        @shelf_info = ShelfInfo.find_by(id: params[:id])
        raise t('api.errors.not_found', :model => 'ShelfInfo', :id => params[:id]) if @shelf_info.nil?
        validate_load_privilege(@shelf_info.shelf.depot)
      end

      def depot_params_create
        resource_params_permit(%w[name depot_code country province city district street street_number house_number postcode telephone])
      end

      def depot_params_update
        resource_params_permit(%w[name country province city district street street_number house_number postcode telephone])
      end

      def shelf_params_create
        resource_params_permit(%w[depot_id depot_area_id column_number row_number spec])
      end

      def shelf_params_update
        resource_params_permit(%w[column_number row_number spec])
      end

      def shelf_info_params_update
        resource_params_permit(%w[spec])
      end

      def validate_shelf_create_params
        depot_id      = params[:depot_id]      || @request_params['depot_id']
        depot_area_id = params[:depot_area_id] || @request_params['depot_area_id']
        validate_depot_and_depot_area(depot_id, depot_area_id)
      end

      def validate_depot_and_depot_area(depot_id, depot_area_id)
        @depot = Depot.find_by(id: depot_id)
        raise t('api.errors.not_found', :model => 'Depot', :id => depot_id) if @depot.nil?
        raise t('api.errors.not_authorized') if @depot.account_id != current_account.id
        @depot_area = @depot.depot_areas.find_by(id: depot_area_id)
        raise t('api.errors.not_found', :model => 'DepotArea', :id => depot_area_id) if @depot_area.nil?
        true
      end


    end
    helpers DepotHelper
  end
end
