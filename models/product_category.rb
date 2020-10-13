# encoding: utf-8
class ProductCategory < ActiveRecord::Base
  has_many :products, :class_name => 'Product'
  has_many :children, :class_name => 'ProductCategory', :foreign_key => :parent_id
  belongs_to :parent, :class_name => 'ProductCategory'

  validates_presence_of   :name, :foreign_name
  # validates_uniqueness_of :name, :foreign_name, :case_sensitive => false
  extend QueryFilter

  #从下向上找父级目录
  def parent_names
    children=self
    parent_names=[self.name]
    while children.parent!=nil
        children=children.parent
        parent_names<<children.name
    end
    parent_names.reverse
  end

  # 给出当前实例的递归子集ID, 包含自身
  def recursive_subset
    result = _recursive_subset_logic_
    result << self.id
    result
  end

  def _recursive_subset_logic_(result=[])
    self.children.each do |child|
      result << child.id
      child._recursive_subset_logic_(result)
    end
    result
  end

  def to_api
    { id: id, parcent_id: parent_id, name: name, foreign_name: foreign_name, hscode: hscode, has_children: children.any?, parent: parent_names }
  end

end
