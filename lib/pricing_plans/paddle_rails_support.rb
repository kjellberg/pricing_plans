# frozen_string_literal: true

module PricingPlans
  module PaddleRailsSupport
    module_function

    def paddle_rails_available?
      defined?(PaddleRails)
    end

    def subscription_active_for?(plan_owner)
      return false unless plan_owner
      return false unless plan_owner.respond_to?(:subscription)

      sub = plan_owner.subscription
      return false unless sub

      (sub.respond_to?(:active?) && sub.active?) ||
        (sub.respond_to?(:trialing?) && sub.trialing?)
    end

    def current_subscription_for(plan_owner)
      return nil unless plan_owner
      return nil unless plan_owner.respond_to?(:subscription)

      sub = plan_owner.subscription
      return sub if sub && ((sub.respond_to?(:active?) && sub.active?) || (sub.respond_to?(:trialing?) && sub.trialing?))
      nil
    end

    def paddle_rails_price_ids_for(subscription)
      return [] unless subscription.respond_to?(:items)
      subscription.items.includes(:price).map { |item| item.price&.paddle_price_id }.compact
    end
  end
end
