require 'rails_helper'
require Rails.root.join('db/migrate/20260918000001_create_crm_deal_conversations.rb')

# crm_deals.conversation_id não tem FK: negócios órfãos (conversa apagada) existem
# em produção. O backfill precisa pulá-los, senão a migration inteira cancela.
RSpec.describe CreateCrmDealConversations do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Funil', slug: 'funil', kind: 'sales') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 1) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:connection) { ActiveRecord::Base.connection }

  def create_deal(**attrs)
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact, title: 'Negócio', **attrs)
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  before do
    connection.drop_table(:crm_deal_conversations, if_exists: true)
  end

  after do
    connection.drop_table(:crm_deal_conversations, if_exists: true)
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  it 'faz backfill da conversa principal e pula negócios cuja conversa não existe mais' do
    linked = create_deal(conversation: conversation)
    orphan = create_deal(contact: create(:contact, account: account))
    connection.execute("UPDATE crm_deals SET conversation_id = 999999999 WHERE id = #{orphan.id}")

    expect { run_migration }.not_to raise_error

    rows = connection.select_rows('SELECT crm_deal_id, conversation_id FROM crm_deal_conversations ORDER BY crm_deal_id')
    expect(rows).to eq([[linked.id, conversation.id]])
  end
end
