# == Schema Information
#
# Table name: captain_inboxes
#
#  id                   :bigint           not null, primary key
#  ai_mode              :string           default("auto"), not null
#  auto_reply_enabled   :boolean          default(TRUE), not null
#  created_at           :datetime         not null
#  enabled              :boolean          default(TRUE), not null
#  handoff_strategy     :string           default("human_request"), not null
#  routing_config       :jsonb            not null
#  updated_at           :datetime         not null
#  captain_assistant_id :bigint           not null
#  inbox_id             :bigint           not null
#
# Indexes
#
#  index_captain_inboxes_on_ai_mode                             (ai_mode)
#  index_captain_inboxes_on_enabled                             (enabled)
#  index_captain_inboxes_on_captain_assistant_id               (captain_assistant_id)
#  index_captain_inboxes_on_captain_assistant_id_and_inbox_id  (captain_assistant_id,inbox_id) UNIQUE
#  index_captain_inboxes_on_inbox_id                           (inbox_id)
#
class CaptainInbox < ApplicationRecord
  AI_MODES = %w[auto supervised paused human_only].freeze
  HANDOFF_STRATEGIES = %w[human_request manual_only].freeze

  belongs_to :captain_assistant, class_name: 'Captain::Assistant'
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
  validates :ai_mode, inclusion: { in: AI_MODES }
  validates :handoff_strategy, inclusion: { in: HANDOFF_STRATEGIES }

  def responsible?
    enabled? && captain_assistant.present?
  end

  def active_for_auto_reply?
    responsible? && auto_reply_enabled? && ai_mode == 'auto'
  end
end
