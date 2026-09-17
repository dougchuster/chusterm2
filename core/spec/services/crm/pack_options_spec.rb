# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::PackOptions do
  let(:account) { create(:account) }

  describe '.for_account' do
    context 'without the crm_universal flag' do
      it 'devolve o payload legado (inclui áreas jurídicas)' do
        result = described_class.for_account(account)

        expect(result[:legal_areas].map { |o| o[:value] }).to include('previdenciario')
        expect(result).not_to have_key(:categories)
      end
    end

    context 'with crm_universal enabled' do
      before { account.enable_features('crm_universal') }

      it 'conta sem pack instalado cai no sales_default — sem áreas jurídicas' do
        result = described_class.for_account(account)

        values = result[:legal_areas].map { |o| o[:value] }
        expect(values).to include('comercial', 'saude', 'varejo')
        expect(values).not_to include('previdenciario', 'trabalhista', 'familia')
        expect(result[:analyst_prompts].join).not_to match(/INSS|jurídic/i)
      end

      it 'conta com pack legal expõe a taxonomia jurídica' do
        Crm::PackInstaller.new(account).install('legal')
        result = described_class.for_account(account)

        values = result[:legal_areas].map { |o| o[:value] }
        expect(values).to include('previdenciario', 'trabalhista', 'familia')
        expect(result[:subcategories]['previdenciario'].map { |o| o[:value] })
          .to include('beneficio_previdenciario')
        expect(result[:field_definitions].map { |f| f[:key] }).to include('numero_processo')
      end

      it 'mescla categorias de múltiplos packs sem duplicar' do
        Crm::PackInstaller.new(account).install('sales_default')
        Crm::PackInstaller.new(account).install('legal')
        result = described_class.for_account(account)

        values = result[:legal_areas].map { |o| o[:value] }
        expect(values.uniq.size).to eq(values.size)
        expect(values).to include('previdenciario', 'varejo')
      end
    end
  end
end
