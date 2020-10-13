# encoding: utf-8
# AbilityHelper 主要用于定义各用户角色数据权限认证方法
module EtWmsService
  class App
    module AbilityHelper

      # 不同的用户角色, 权限描述如下
      # 1. super_admin     - p0, 超级管理员, 查询权限: ALL, 操作权限: 无
      # 2. admin           - p1, 管理员, 查询权限: Channel, 操作权限: 无
      # 3. staff           - p1, admin的工作人员, 查询权限: Channel, 操作权限: 后端
      # 4. wh_admin        - p1, 仓库admin, 查询权限: Channel, 操作权限: 后端
      # 5. wh_staff        - p1, 仓库工作人员, 查询权限: Channel, 操作权限: 后端
      # 6. consignor       - p2, 货主, 查询权限: Channel, 操作权限: 前端
      # 7. c_staff         - p2, 货主工作人员, 查询权限: Channel, 操作权限: 前端

      ##
      # 角色枚举值, 顺序即优先级, 插入新角色时需要注意
      def roles_enum
        %w[super_admin admin staff wh_admin wh_staff consignor c_staff]
      end

      def prior_role(account)
        (roles_enum & account.roles.pluck(:name)).first || account.roles.pluck(:name).first
      end

      def query_privilege
        prior_role(current_account) == 'super_admin' ? {} : { :channel_auth => current_account.channels[0].name }
      end

    end
    helpers AbilityHelper
  end
end
