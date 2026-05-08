module SuperAdmin::FeaturesHelper
  def self.available_features
    YAML.load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
  end

  def self.plan_details
    plan = ChusteRMHub.pricing_plan.to_s
    quantity = ChusteRMHub.pricing_plan_quantity

    if plan == 'premium'
      helpers.safe_join(
        [
          'You are currently on the ',
          helpers.tag.span(plan, class: 'font-semibold'),
          ' plan with ',
          helpers.tag.span("#{quantity} agents", class: 'font-semibold'),
          '.'
        ]
      )
    else
      helpers.safe_join(
        [
          'You are currently on the ',
          helpers.tag.span(plan, class: 'font-semibold'),
          ' edition plan.'
        ]
      )
    end
  end

  def self.helpers
    ActionController::Base.helpers
  end
end
