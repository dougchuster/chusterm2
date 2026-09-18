require 'rails_helper'

# Check-up 2026-09-18: sem tradução do framework, os 422 do CRM devolviam
# "Validation failed: Name can't be blank" mesmo com default_locale = pt_BR.
RSpec.describe 'config/locales/rails.pt_BR.yml', type: :locale do # rubocop:disable RSpec/DescribeClass
  it 'traduz mensagens de validação e nomes de atributos comuns' do
    I18n.with_locale(:pt_BR) do
      pipeline = CrmPipeline.new
      pipeline.valid?

      expect(pipeline.errors.full_messages).to include('Nome não pode ficar em branco')
      expect(pipeline.errors.full_messages.join).not_to include("can't be blank")
    end
  end

  it 'traduz o prefixo de ActiveRecord::RecordInvalid' do
    I18n.with_locale(:pt_BR) do
      expect { CrmLossReason.create!(name: '') }
        .to raise_error(ActiveRecord::RecordInvalid, /\AA validação falhou: /)
    end
  end
end
