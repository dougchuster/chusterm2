class AddAnalysisNoticeToCaptainConversationStates < ActiveRecord::Migration[7.0]
  def change
    add_column :captain_conversation_states, :analysis_notice_sent_at, :datetime
    add_index :captain_conversation_states, :analysis_notice_sent_at
  end
end
