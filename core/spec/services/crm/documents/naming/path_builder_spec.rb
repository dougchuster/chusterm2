require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §5.6 — a mesma árvore serve tela, espelho, Drive
# e .zip. Por isso o PathBuilder precisa ser determinístico.
RSpec.describe Crm::Documents::Naming::PathBuilder do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Maria da Silva Souza') }
  let(:builder) { described_class.new }

  before { Crm::Documents::Defaults.ensure!(account) }

  def upload(folder:, **attrs)
    CrmDocument.create!(
      { account: account, contact: contact, crm_document_folder: folder, source: 'upload',
        doc_type: 'rg', content_type: 'application/pdf', original_filename: 'rg.pdf' }.merge(attrs)
    )
  end

  describe '.client_folder_name' do
    it 'combina nome e código de seis dígitos, sem CPF' do
      expect(described_class.client_folder_name(contact))
        .to eq("Maria da Silva Souza · C#{contact.id.to_s.rjust(6, '0')}")
    end

    it 'usa um nome genérico quando o contato não tem nome' do
      contact.update!(name: '')

      expect(described_class.client_folder_name(contact)).to start_with('Sem nome · C')
    end
  end

  describe '.deal_folder_name' do
    it 'usa ano, número interno e título do negócio' do
      pipeline = account.crm_pipelines.first || account.crm_pipelines.create!(name: 'P', slug: 'p', kind: 'legal_intake')
      stage = pipeline.crm_pipeline_stages.first ||
              pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
      deal = account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage,
                                       title: 'Aposentadoria por Idade', created_at: Time.zone.parse('2026-05-01'))

      expect(described_class.deal_folder_name(deal))
        .to eq("2026-#{deal.id.to_s.rjust(4, '0')} · Aposentadoria por Idade")
    end
  end

  describe '#path_for' do
    it 'monta o caminho completo a partir do contato e das pastas' do
      root = Crm::Documents::DrawerProvisioner.new(contact).ensure!
      pessoais = root.find { |f| f.slot == 'pessoais' }
      document = upload(folder: pessoais, description: 'Frente e verso', created_at: Time.zone.parse('2026-09-22 12:00'))

      expect(builder.path_for(document)).to eq(
        ['Clientes', described_class.client_folder_name(contact), '01 Documentos Pessoais',
         '2026-09-22 — RG — Frente e verso.pdf']
      )
    end

    it 'desempata nomes iguais na mesma pasta pela ordem de criação' do
      folder = Crm::Documents::DrawerProvisioner.new(contact).ensure!.find { |f| f.slot == 'pessoais' }
      first = upload(folder: folder, created_at: Time.zone.parse('2026-09-22 12:00'))
      second = upload(folder: folder, created_at: Time.zone.parse('2026-09-22 13:00'))

      expect(builder.path_for(first).last).to eq('2026-09-22 — RG.pdf')
      expect(builder.path_for(second).last).to eq('2026-09-22 — RG (2).pdf')
    end

    it 'ignora documentos arquivados no desempate' do
      folder = Crm::Documents::DrawerProvisioner.new(contact).ensure!.find { |f| f.slot == 'pessoais' }
      upload(folder: folder, created_at: Time.zone.parse('2026-09-22 12:00'), archived_at: Time.current)
      active = upload(folder: folder, created_at: Time.zone.parse('2026-09-22 13:00'))

      expect(builder.path_for(active).last).to eq('2026-09-22 — RG.pdf')
    end
  end
end
