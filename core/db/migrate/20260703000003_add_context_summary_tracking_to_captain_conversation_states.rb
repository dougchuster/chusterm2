# PERF-06 (parte 2): rastreia até qual mensagem o context_summary cobre —
# o resumo só é regenerado quando a janela de contexto avança além dele.
class AddContextSummaryTrackingToCaptainConversationStates < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_conversation_states, :context_summary_upto_message_id, :bigint
  end
end
