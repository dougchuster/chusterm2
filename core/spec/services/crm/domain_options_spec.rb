require 'rails_helper'

RSpec.describe Crm::DomainOptions do
  describe '.canonical_legal_area' do
    it 'preserves the historical keys and normalizes discarded-plan aliases' do
      expect(described_class.canonical_legal_area('civel')).to eq('civel')
      expect(described_class.canonical_legal_area('civil')).to eq('civel')
      expect(described_class.canonical_legal_area('penal')).to eq('criminal')
      expect(described_class.canonical_legal_area('outros')).to eq('outro')
    end
  end

  describe 'deal persistence and filtering' do
    let(:account) { create(:account) }
    let(:pipeline) { CrmPipeline.create!(account: account, name: 'Pipeline', position: 1) }
    let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Entrada', position: 1) }

    def create_deal(title:, legal_area:)
      CrmDeal.create!(
        account: account,
        crm_pipeline: pipeline,
        crm_pipeline_stage: stage,
        title: title,
        legal_area: legal_area
      )
    end

    it 'stores new aliases with the established key' do
      deal = create_deal(title: 'Contrato', legal_area: 'civil')

      expect(deal.legal_area).to eq('civel')
    end

    it 'finds both established and temporary alias values' do
      established = create_deal(title: 'Registro histórico', legal_area: 'civel')
      temporary = create_deal(title: 'Registro temporário', legal_area: 'civel')
      temporary.update_column(:legal_area, 'civil') # rubocop:disable Rails/SkipsModelValidations

      result = Crm::DealFilterService.new(
        scope: account.crm_deals,
        filters: { legal_area: 'civel' }
      ).perform

      expect(result).to contain_exactly(established, temporary)
    end
  end
end
