# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::PackInstaller do
  let(:account) { create(:account) }

  describe '#install' do
    it 'registra o pack e cria tipos de atividade e campos do pack' do
      described_class.new(account).install('sales_default')

      pack_row = account.crm_account_packs.find_by(slug: 'sales_default')
      expect(pack_row).to be_present
      expect(pack_row.installed_at).to be_present
      expect(account.crm_activity_types.pluck(:key)).to include('ligacao', 'reuniao', 'follow_up')
      expect(account.crm_field_definitions.pluck(:key)).to include('quantidade')
    end

    it 'é idempotente — reinstalar não duplica registros' do
      installer = described_class.new(account)
      installer.install('legal')
      expect { installer.install('legal') }
        .not_to(change { account.crm_activity_types.count })
      expect(account.crm_account_packs.where(slug: 'legal').count).to eq(1)
    end

    it 'falha com erro claro para pack inexistente' do
      expect { described_class.new(account).install('nao_existe') }
        .to raise_error(Crm::Pack::UnknownPackError, /nao_existe/)
    end
  end

  describe 'legal pack' do
    it 'expõe taxonomia jurídica somente quando instalado' do
      described_class.new(account).install('legal')

      keys = account.crm_activity_types.pluck(:key)
      expect(keys).to include('analise_documental', 'envio_contrato', 'revisao_juridica')
      expect(account.crm_field_definitions.pluck(:key)).to include('numero_processo', 'parte_contraria')
    end
  end
end
