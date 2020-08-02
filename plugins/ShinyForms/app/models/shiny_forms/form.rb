# frozen_string_literal: true

module ShinyForms
  # Model for ShinyCMS forms
  class Form < ApplicationRecord
    # Specify policy class for Pundit
    def policy_class
      ::Admin::FormPolicy
    end
  end
end
