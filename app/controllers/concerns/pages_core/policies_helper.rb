module PagesCore
  module PoliciesHelper
    extend ActiveSupport::Concern

    included do
      helper_method :policy
    end

    module ClassMethods
      def require_authorization(collection, member, options = {})
        options = default_options.merge(options)
        before_action do |controller|
          action = params[:action].to_sym
          if options[:collection].include?(action)
            verify_policy_with_proc(controller, collection)
          elsif options[:member].include?(action)
            verify_policy_with_proc(controller, member)
          end
        end
      end

      def default_options
        {
          collection: %i[index new create],
          member:     %i[show edit update destroy]
        }
      end
    end

    def policy(object)
      Policy.for(current_user, object)
    end

    def verify_policy_with_proc(controller, record)
      record = controller.instance_eval(&record) if record.is_a?(Proc)
      verify_policy(record)
    end

    def verify_policy(record)
      return true if policy(record).public_send(action_name + "?")
      raise PagesCore::NotAuthorized
    end
  end
end
