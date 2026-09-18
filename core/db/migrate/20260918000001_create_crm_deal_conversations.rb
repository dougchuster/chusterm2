class CreateCrmDealConversations < ActiveRecord::Migration[7.1]
  def up
    create_table :crm_deal_conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :crm_deal, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true

      t.timestamps
    end

    add_index :crm_deal_conversations, %i[crm_deal_id conversation_id], unique: true, name: 'idx_crm_deal_conversations_unique'
    add_index :crm_deal_conversations, %i[account_id conversation_id], name: 'idx_crm_deal_conversations_account'

    # Backfill: a conversa primária (crm_deals.conversation_id) vira o primeiro
    # elo do join; a coluna segue existindo como "conversa principal".
    execute <<~SQL.squish
      INSERT INTO crm_deal_conversations (account_id, crm_deal_id, conversation_id, created_at, updated_at)
      SELECT account_id, id, conversation_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM crm_deals
      WHERE conversation_id IS NOT NULL
    SQL
  end

  def down
    drop_table :crm_deal_conversations
  end
end
