import {
  chatConversationIdentifiers,
  crmConversationIdentifiers,
  crmConversationUrl,
} from '../conversationIdentifier';

describe('conversationIdentifier', () => {
  const databaseId = 912;
  const displayId = 37;

  it('keeps the Chatwoot display id separate from the database id', () => {
    expect(
      chatConversationIdentifiers({
        id: displayId,
        display_id: displayId,
        database_id: databaseId,
      })
    ).toEqual({ databaseId, displayId });
  });

  it('keeps CRM foreign keys separate from display ids', () => {
    expect(
      crmConversationIdentifiers({
        conversation_id: databaseId,
        conversation_display_id: displayId,
        conversation: { id: databaseId, display_id: displayId },
      })
    ).toEqual({ databaseId, displayId });
  });

  it('uses only the display id in Chatwoot routes', () => {
    const record = {
      conversation_id: databaseId,
      conversation_display_id: displayId,
    };

    expect(crmConversationUrl({ accountId: 5, record })).toBe(
      '/app/accounts/5/conversations/37'
    );
  });

  it('does not fall back to the database id for a Chatwoot route', () => {
    expect(
      crmConversationUrl({
        accountId: 5,
        record: { conversation_id: databaseId },
      })
    ).toBe('');
  });
});
