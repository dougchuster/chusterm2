export const MOBILE_CONVERSATION_BREAKPOINT = 640;

export const shouldCloseContactSidebarOnConversationOpen = ({
  conversationId,
  isContactSidebarOpen,
  windowWidth,
}) =>
  Boolean(conversationId) &&
  Boolean(isContactSidebarOpen) &&
  windowWidth < MOBILE_CONVERSATION_BREAKPOINT;
