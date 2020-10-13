# encoding: utf-8
require 'carrierwave/orm/activerecord'
class ProductSalesProperty < ActiveRecord::Base
  belongs_to :product, :class_name => 'Product'

  mount_uploader :thumbnail, FileUploader

  def to_api
      {
        id:                   id,
        brand:                brand,
        model:                model,
        currency:             currency,
        price:                price,
        weight:               weight,
        clearance_attributes: clearance_attributes
      }
  end

  extend QueryFilter
end
