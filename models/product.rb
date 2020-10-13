# encoding: utf-8
class Product < ActiveRecord::Base
  belongs_to :account, :class_name => 'Account'
  belongs_to :product_category, :class_name => 'ProductCategory'
  belongs_to :service_category, :class_name => 'ServiceCategory'
  has_one :product_sales_property, :class_name => 'ProductSalesProperty'

  validates_presence_of   :sku_code
  validates_uniqueness_of :sku_code, :case_sensitive => false
  validates_presence_of   :barcode
  validates_presence_of   :name, :foreign_name

  before_validation :setup

  extend QueryFilter

  def to_api
    {
      id:               id,
      sku_code:         sku_code,
      barcode:          barcode,
      name:             name,
      foreign_name:     foreign_name,
      description:      description,
      sku_owner:        account.email,
      product_category: product_category.try(:name),
      service_category: service_category.try(:name),
      created_at:       created_at
    }
  end

  def to_api_search
    to_api.merge!(product_sales_property: product_sales_property.try(&:to_api))
  end

  def to_api_show
    data = {product:to_api}
    data.merge!(product_category:product_category.try(&:to_api))
    data.merge!(service_category:service_category.try(&:to_api))
    data.merge!(product_sales_property:product_sales_property.try(&:to_api))
    if product_sales_property
      if product_sales_property.thumbnail.present?
          data.merge!(thumbnail_identifier:product_sales_property.thumbnail_identifier)
          data.merge!(thumbnail:Base64.encode64(File.open(product_sales_property.thumbnail.path).read))
      end
    end
    data
  end

  # 产品删除条件
  def can_delete?
    true
  end

  private
  def setup
    self.sku_code = sku_code.try(:upcase)
    self.barcode  = barcode.try(:upcase)
  end

end