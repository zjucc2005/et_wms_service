# encoding: utf-8
module EtWmsService
  class App
    module AccountHelper

      def account_params_create
        resource_params_permit(
          %w[email nickname telephone password password_confirmation account_group_ids role_ids channel_ids
             firstname lastname sex country city address company qq_num wechat_num extra_email memo]
        )
      end

      def account_params_update
        resource_params_permit(
          %w[nickname telephone account_group_ids role_ids channel_ids
             firstname lastname sex country city address company qq_num wechat_num extra_email memo]
        )
      end

      def account_params_update_password
        resource_params_permit(%w[current_password password password_confirmation])
      end

      def account_group_params
        resource_params_permit(%w(name role_ids))
      end

      def channel_params
        resource_params_permit(%w(name parent_id))
      end

      #编辑用户--编辑用户信息, 包括添加删除关联信息
      def edit_account
        status = false
        msg=[]
        account = Account.where(id:params[:id]).first
        if account.present?
          begin
            account.update_attributes!("nickname"=>params[:nickname],"telephone"=>params[:telephone])
            #修改用户组
            if params[:account_group_ids].present?
              now_account_groups = AccountGroup.where(id:params[:account_group_ids])
              account.account_groups = now_account_groups
            end
            #修改角色
            if params[:role_ids].present?
              now_account_roles = Role.where(id:params[:role_ids])
              account.roles = now_account_roles
            end
            account.save
            status = true
          rescue => e
            msg<<e.message
          end
        else
          msg<<"can not find account:id=#{params[:id]}"
        end
        return [status,msg]
      end



      def check_account_role
        status = false
        account = Account.find_by(email:params[:my_email])
        ac_and_r_list = AccountAndRole.where(account_id:account.id)
        role = Role.where(id:ac_and_r_list.map(&:role_id)).find_by(name:"admin")
        status = true if role
        return status
      end

      # 验证创建用户时的角色关系
      def validates_roles_relation(account_params)
        # 获取新用户角色
        role_names = Role.where(id: account_params['role_ids']).pluck(:name)

        if role_names.include?('c_staff')
          # 创建 c_staff 时, consignor_email 字段不能为空且有效
          if account_params['consignor_email'].present?
            c_account = Account.where(email: account_params['consignor_email']).first
            raise t('api.errors.invalid_consignor_email') if c_account.nil? || c_account.roles.pluck(:name).exclude?('consignor')

            account_params['channel_ids'] = c_account.channel_ids  # 验证通过, 将货主渠道赋值上去
          else
            raise t('api.errors.blank', :field => 'consignor_email')
          end
        end

        account_params.delete('consignor_email')  # 删除 consignor_email 字段
        account_params
      end

    end
    helpers AccountHelper
  end
end
