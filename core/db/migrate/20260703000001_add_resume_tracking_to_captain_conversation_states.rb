# BUG-03: retomada manual da IA vira dado estruturado (resume_source) em vez
# de comparação com a magic string 'IA retomada manualmente' no handoff_reason.
class AddResumeTrackingToCaptainConversationStates < ActiveRecord::Migration[7.1]
  def change
    change_table :captain_conversation_states, bulk: true do |t|
      t.string :resume_source
      t.datetime :resumed_at
      t.bigint :resumed_by_id
    end

    add_index :captain_conversation_states, :resumed_by_id
  end
end
