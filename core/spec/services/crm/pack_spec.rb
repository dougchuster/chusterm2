# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Pack do
  describe '.find!' do
    it 'carrega um pack existente' do
      pack = described_class.find!('sales_default')

      expect(pack.slug).to eq('sales_default')
      expect(pack.categories).to be_present
    end

    it 'rejeita slug com traversal de caminho antes de tocar o disco' do
      expect { described_class.find!('../../config/database') }
        .to raise_error(Crm::Pack::UnknownPackError, /inválido/)
    end

    it 'rejeita slug desconhecido' do
      expect { described_class.find!('nao_existe') }
        .to raise_error(Crm::Pack::UnknownPackError, /não existe/)
    end
  end

  describe '.definition_for' do
    it 'parseia o YAML uma vez por slug enquanto o arquivo não muda' do
      described_class.definitions_cache.delete('sales_default')
      allow(described_class).to receive(:parse_definition!).and_call_original

      described_class.find!('sales_default')
      described_class.find!('sales_default')

      expect(described_class).to have_received(:parse_definition!).once
    end
  end
end
