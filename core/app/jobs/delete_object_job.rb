class DeleteObjectJob < ApplicationJob
  queue_as :low

  BATCH_SIZE = 5_000

  def perform(object, user = nil, ip = nil)
    # Pre-purge heavy associations for large objects to avoid
    # timeouts & race conditions due to destroy_async fan-out.
    purge_heavy_associations(object)
    purge_legacy_inbox_dependencies(object)
    object.destroy!
    process_post_deletion_tasks(object, user, ip)
  end

  def process_post_deletion_tasks(object, user, ip); end

  private

  def heavy_associations
    {
      Account => %i[conversations contacts inboxes reporting_events],
      Inbox => %i[conversations contact_inboxes reporting_events]
    }.freeze
  end

  def purge_heavy_associations(object)
    klass = heavy_associations.keys.find { |k| object.is_a?(k) }
    return unless klass

    heavy_associations[klass].each do |assoc|
      next unless object.respond_to?(assoc)

      batch_destroy(object.public_send(assoc))
    end
  end

  def purge_legacy_inbox_dependencies(object)
    return unless object.is_a?(Inbox)

    %w[novacrm_ai_flows nova_ai_agent_inboxes].each do |table_name|
      delete_legacy_rows(table_name, object.id)
    end
  end

  def delete_legacy_rows(table_name, inbox_id)
    connection = ActiveRecord::Base.connection
    return unless connection.table_exists?(table_name)
    return unless connection.column_exists?(table_name, :inbox_id)

    quoted_table = connection.quote_table_name(table_name)
    connection.execute("DELETE FROM #{quoted_table} WHERE inbox_id = #{inbox_id.to_i}")
  end

  def batch_destroy(relation)
    relation.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch.each(&:destroy!)
    end
  end
end

DeleteObjectJob.prepend_mod_with('DeleteObjectJob')
