# ARQ-04/UX-04: motivo do handoff como código estruturado (ex.: human_takeover,
# customer_contact, unreadable_media, ai_handoff, score_auto_handoff) além do
# texto livre — base da "Central de IA".
class AddHandoffReasonCodeToCaptainConversationStates < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_conversation_states, :handoff_reason_code, :string
    add_index :captain_conversation_states, :handoff_reason_code
  end
end
