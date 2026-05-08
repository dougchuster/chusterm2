class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information
    # ActsAsTaggableOn::Taggable::Cache removed in acts_as_taggable_on >= 10.0
    # Cache is re-initialized automatically on next app boot
  end
end
