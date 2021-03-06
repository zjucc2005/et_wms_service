# encoding: utf-8
# ModelHelper 主要用于定义各 model 之间通用的参数/字段等的组装和认证helper方法
module EtWmsService
  class App
    module ModelHelper

      def validate_array(resource)
        raise t('api.errors.not_array', :field => resource) unless @request_params[resource].is_a?(Array)
      end

      def validate_hash(resource)
        raise t('api.errors.not_hash', :field => resource) unless @request_params[resource].is_a?(Hash)
      end

      def validate_presence(resource)
        raise t('api.errors.blank', :field => resource) if @request_params[resource].blank?
      end

      def validate_string(resource)
        raise t('api.errors.not_string', :field => resource) unless @request_params[resource].is_a?(String)
      end

      def resource_params_permit(array=[])
        result = {}
        array.each do |field|
          if params[field]
            result[field] = params[field]
          elsif @request_params.try(:[], field)
            result[field] = @request_params[field]
          end
        end
        result
      end

    end
    helpers ModelHelper
  end
end
