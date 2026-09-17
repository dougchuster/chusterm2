# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass -- spec cross-cutting da fundação
# universal (CrmDeal dual-write + CrmActivity tipos + AccountInitializer).
RSpec.describe 'CRM universal foundation' do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.default_first.first }
  let(:stage) { pipeline.crm_pipeline_stages.first }

  def build_deal(attrs = {})
    CrmDeal.new({ account: account, crm_pipeline: pipeline, crm_pipeline_stage: stage,
                  title: 'Deal teste' }.merge(attrs))
  end

  describe 'CrmDeal category/subcategory dual-write' do
    it 'legal_area preenche category (legado -> universal)' do
      deal = build_deal(legal_area: 'previdenciario', case_type: 'beneficio_previdenciario')
      deal.valid?

      expect(deal.category).to eq('previdenciario')
      expect(deal.subcategory).to eq('beneficio_previdenciario')
    end

    it 'category preenche legal_area (universal -> legado)' do
      deal = build_deal(category: 'saude', subcategory: 'consulta')
      deal.valid?

      expect(deal.legal_area).to eq('saude')
      expect(deal.case_type).to eq('consulta')
    end

    it 'alias legado é canonicalizado mesmo quando vem via category' do
      deal = build_deal(category: 'civil')
      deal.valid?

      expect(deal.legal_area).to eq('civel')
      expect(deal.category).to eq('civil') # category preserva o que o usuário escreveu
    end
  end

  describe 'CrmActivity tipos por conta' do
    def build_activity(kind)
      CrmActivity.new(account: account, kind: kind, title: 'Atividade teste')
    end

    it 'rejeita tipo desconhecido fora do modo universal' do
      expect(build_activity('tipo_inventado')).not_to be_valid
    end

    it 'aceita tipo instalado pelo pack quando crm_universal está ativo' do
      account.enable_features('crm_universal')
      Crm::PackInstaller.new(account).install('sales_default')

      expect(build_activity('demonstracao')).to be_valid
    end

    it 'KINDS legados continuam válidos mesmo com pack instalado' do
      account.enable_features('crm_universal')
      Crm::PackInstaller.new(account).install('sales_default')

      expect(build_activity('revisao_juridica')).to be_valid
    end
  end

  describe 'Crm::AccountInitializer' do
    it 'instala o pack sales_default em conta nova' do
      fresh_account = create(:account)
      Crm::AccountInitializer.new(fresh_account).perform

      expect(fresh_account.crm_account_packs.pluck(:slug)).to eq(['sales_default'])
      expect(fresh_account.crm_activity_types).not_to be_empty
    end

    it 'não duplica nem sobrescreve packs existentes' do
      Crm::PackInstaller.new(account).install('legal')
      expect { Crm::AccountInitializer.new(account).perform }
        .not_to(change { account.crm_account_packs.count })

      # sales_default (install da conta) + legal (instalado manualmente)
      expect(account.crm_account_packs.pluck(:slug)).to match_array(%w[sales_default legal])
    end
  end
end

# rubocop:enable RSpec/DescribeClass
