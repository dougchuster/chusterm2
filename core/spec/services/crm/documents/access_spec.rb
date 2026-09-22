require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §10 — documento de cliente é dado sensível:
# administrador vê tudo; agente vê os contatos que atende (conversa em inbox
# dele ou negócio visível para ele).
RSpec.describe Crm::Documents::Access do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:served) { create(:contact, account: account) }
  let(:stranger) { create(:contact, account: account) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, contact: served)
    create(:conversation, account: account, inbox: other_inbox, contact: stranger)
  end

  it 'deixa o administrador ver qualquer contato' do
    expect(described_class.new(admin, account).contact_visible?(stranger)).to be(true)
  end

  it 'deixa o agente ver o contato que ele atende' do
    expect(described_class.new(agent, account).contact_visible?(served)).to be(true)
  end

  it 'esconde do agente o contato de outra inbox' do
    expect(described_class.new(agent, account).contact_visible?(stranger)).to be(false)
  end

  it 'libera o contato quando há um negócio do qual o agente é dono' do
    pipeline = account.crm_pipelines.create!(name: 'P', slug: 'p-access', kind: 'legal_intake')
    stage = pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: stranger,
                              inbox: other_inbox, owner_id: agent.id, title: 'Caso')

    expect(described_class.new(agent, account).contact_visible?(stranger)).to be(true)
  end

  # Achado CRÍTICO da revisão de segurança (22/09): no funil, negócio sem
  # inbox é visível para todo agente. Isso não pode abrir documento sensível.
  it 'não libera o contato só porque existe um negócio sem inbox' do
    pipeline = account.crm_pipelines.create!(name: 'P', slug: 'p-sem-inbox', kind: 'legal_intake')
    stage = pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: stranger,
                              inbox: nil, title: 'Caso criado à mão')

    expect(described_class.new(agent, account).contact_visible?(stranger)).to be(false)
  end

  it 'libera o contato quando o negócio é do time do agente' do
    team = create(:team, account: account)
    create(:team_member, team: team, user: agent)
    pipeline = account.crm_pipelines.create!(name: 'P', slug: 'p-time', kind: 'legal_intake')
    stage = pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: stranger,
                              team_id: team.id, title: 'Caso do time')

    expect(described_class.new(agent, account).contact_visible?(stranger)).to be(true)
  end

  # Revisão de segurança (22/09, formulários): negócio sem inbox de outro
  # agente é outro caso do mesmo cliente — não pode receber documento por ele.
  it 'só oferece para arquivar os negócios do agente, não o caso sem inbox de outro' do
    # Um funil por caso: o funil só aceita um lead aberto por contato.
    deal_for = lambda do |attrs|
      pipeline = account.crm_pipelines.create!(name: attrs[:title], slug: "p-#{SecureRandom.hex(3)}", kind: 'legal_intake')
      stage = pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
      account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: served, **attrs)
    end
    mine = deal_for.call(title: 'Trabalhista', owner_id: agent.id)
    by_inbox = deal_for.call(title: 'Da inbox', inbox: inbox)
    deal_for.call(title: 'Família', owner_id: admin.id)

    expect(described_class.new(agent, account).deals.pluck(:id)).to contain_exactly(mine.id, by_inbox.id)
    expect(described_class.new(admin, account).deals.count).to eq(3)
  end

  it 'filtra documentos pelo mesmo critério' do
    Crm::Documents::Defaults.ensure!(account, preset: 'legal')
    mine = CrmDocument.create!(account: account, contact: served, source: 'upload', original_filename: 'a.pdf')
    CrmDocument.create!(account: account, contact: stranger, source: 'upload', original_filename: 'b.pdf')

    expect(described_class.new(agent, account).documents.pluck(:id)).to eq([mine.id])
  end
end
