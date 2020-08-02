# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ShinyForms Admin', type: :request do
  before :each do
    admin = create :form_admin
    sign_in admin
  end

  describe 'GET /admin/forms/new' do
    it 'loads the page to add a new form handler' do
      get shiny_forms.new_form_path

      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_title I18n.t( 'shiny_forms.admin.forms.new.title' ).titlecase
    end
  end
end
