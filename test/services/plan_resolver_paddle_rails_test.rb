# frozen_string_literal: true

require "test_helper"

class PlanResolverPaddleRailsTest < ActiveSupport::TestCase
  include TestConfigurationHelper

  def setup
    # Define PaddleRails constant so paddle_rails_available? returns true
    Object.const_set(:PaddleRails, Module.new) unless defined?(PaddleRails)

    PricingPlans.reset_configuration!

    PricingPlans.configure do |config|
      config.default_plan = :free

      config.plan :free do
        price 0
      end

      config.plan :pro do
        price 29
        paddle_rails_price month: "pri_pro_monthly", year: "pri_pro_yearly"
      end

      config.plan :enterprise do
        price 99
        paddle_rails_price "pri_enterprise_single"
      end
    end
  end

  def teardown
    super
    Object.send(:remove_const, :PaddleRails) if defined?(PaddleRails)
  end

  def test_resolves_plan_from_active_paddle_rails_subscription
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_pro_monthly"], active: true)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :pro, plan.key
  end

  def test_resolves_plan_from_yearly_price
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_pro_yearly"], active: true)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :pro, plan.key
  end

  def test_resolves_plan_from_string_paddle_rails_price
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_enterprise_single"], active: true)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :enterprise, plan.key
  end

  def test_resolves_trialing_subscription
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_pro_monthly"], active: false, trialing: true)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :pro, plan.key
  end

  def test_falls_back_to_default_when_no_subscription
    org = create_organization

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :free, plan.key
  end

  def test_falls_back_to_default_when_subscription_inactive
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_pro_monthly"], active: false, trialing: false)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :free, plan.key
  end

  def test_falls_back_to_default_when_price_id_unknown
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_unknown_999"], active: true)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :free, plan.key
  end

  def test_manual_assignment_overrides_paddle_rails
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_pro_monthly"], active: true)

    PricingPlans::Assignment.assign_plan_to(org, :enterprise)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :enterprise, plan.key
  end

  def test_falls_back_to_default_when_paddle_rails_not_available
    Object.send(:remove_const, :PaddleRails) if defined?(PaddleRails)

    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: ["pri_pro_monthly"], active: true)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :free, plan.key
  end

  def test_empty_price_ids_falls_back_to_default
    org = create_organization
    stub_paddle_rails_subscription(org, price_ids: [], active: true)

    plan = PricingPlans::PlanResolver.effective_plan_for(org)
    assert_equal :free, plan.key
  end

  private

  def stub_paddle_rails_subscription(org, price_ids:, active: true, trialing: false)
    items = price_ids.map do |pid|
      price = OpenStruct.new(paddle_price_id: pid)
      OpenStruct.new(price: price)
    end

    # Make items respond to includes (no-op in test) and map
    items_relation = items
    items_relation.define_singleton_method(:includes) { |*_args| self }

    subscription = OpenStruct.new(
      active?: active,
      trialing?: trialing,
      items: items_relation
    )

    org.define_singleton_method(:subscription) { subscription }
  end
end
