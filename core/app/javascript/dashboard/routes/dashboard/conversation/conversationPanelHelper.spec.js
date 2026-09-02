import {
  MOBILE_CONVERSATION_BREAKPOINT,
  shouldCloseContactSidebarOnConversationOpen,
} from './conversationPanelHelper';

describe('conversationPanelHelper', () => {
  it('closes a persisted contact sidebar when a conversation opens on mobile', () => {
    expect(
      shouldCloseContactSidebarOnConversationOpen({
        conversationId: 55,
        isContactSidebarOpen: true,
        windowWidth: MOBILE_CONVERSATION_BREAKPOINT - 1,
      })
    ).toBe(true);
  });

  it('keeps the persisted sidebar behavior on desktop', () => {
    expect(
      shouldCloseContactSidebarOnConversationOpen({
        conversationId: 55,
        isContactSidebarOpen: true,
        windowWidth: MOBILE_CONVERSATION_BREAKPOINT,
      })
    ).toBe(false);
  });

  it.each([
    { conversationId: null, isContactSidebarOpen: true },
    { conversationId: 55, isContactSidebarOpen: false },
  ])(
    'does not update UI settings without an open conversation sidebar',
    ({ conversationId, isContactSidebarOpen }) => {
      expect(
        shouldCloseContactSidebarOnConversationOpen({
          conversationId,
          isContactSidebarOpen,
          windowWidth: 390,
        })
      ).toBe(false);
    }
  );
});
