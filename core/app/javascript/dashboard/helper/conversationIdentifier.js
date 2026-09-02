const isPresent = value =>
  value !== undefined && value !== null && value !== '';

const firstPresent = (...values) =>
  values.find(value => isPresent(value)) ?? null;

/**
 * Chatwoot conversation payloads keep `id` as the account-scoped display ID
 * for backwards compatibility. `database_id` is the internal primary key.
 */
export const chatConversationIdentifiers = conversation => ({
  databaseId: firstPresent(conversation?.database_id),
  displayId: firstPresent(conversation?.display_id, conversation?.id),
});

/** CRM records expose the conversation FK and display ID as separate fields. */
export const crmConversationIdentifiers = record => ({
  databaseId: firstPresent(record?.conversation_id, record?.conversation?.id),
  displayId: firstPresent(
    record?.conversation_display_id,
    record?.conversation?.display_id
  ),
});

export const crmConversationUrl = ({ accountId, record }) => {
  const { displayId } = crmConversationIdentifiers(record);
  if (!isPresent(accountId) || !isPresent(displayId)) return '';

  return `/app/accounts/${accountId}/conversations/${displayId}`;
};
