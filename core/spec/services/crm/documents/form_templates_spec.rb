require 'rails_helper'

RSpec.describe Crm::Documents::FormTemplates do
  %w[geral legal clinic real_estate education].each do |preset|
    it "gera um formulário inicial válido no modelo #{preset}" do
      account = create(:account)
      Crm::Documents::Defaults.ensure!(account, preset: preset)

      form = account.crm_document_forms.new(described_class.default_attributes(account))

      expect(form).to be_valid, form.errors.full_messages.to_sentence
    end
  end
end
