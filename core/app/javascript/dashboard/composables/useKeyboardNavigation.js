import {
  ref,
  reactive,
  computed,
  onMounted,
  onUnmounted,
  getCurrentInstance,
} from 'vue';
import { emitter } from 'shared/helpers/mitt';
import {
  isActiveElementTypeable,
  isEscape,
} from 'shared/helpers/KeyboardHelpers';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import { CMD_RESOLVE_CONVERSATION } from 'dashboard/helper/commandbar/events';

export const INBOX_SHORTCUT_KEYS = {
  NAVIGATE_NEXT: ['j', 'J', 'ArrowDown', 'Down'],
  NAVIGATE_PREVIOUS: ['k', 'K', 'ArrowUp', 'Up'],
  RESOLVE_CONVERSATION: ['e', 'E'],
  FOCUS_COMPOSER: ['r', 'R'],
  OPEN_CANNED: ['/'],
  TOGGLE_NOTE_MODE: ['Alt+p', 'Alt+P', 'Alt+KeyP'],
};

export const BUS_KEYBOARD_EVENTS = {
  NAVIGATE_CONVERSATION: 'KEYBOARD_NAVIGATE_CONVERSATION',
  RESOLVE_CONVERSATION: 'KEYBOARD_RESOLVE_CONVERSATION',
  FOCUS_COMPOSER: 'KEYBOARD_FOCUS_COMPOSER',
  OPEN_CANNED: 'KEYBOARD_OPEN_CANNED_RESPONSES',
  TOGGLE_REPLY_MODE: 'KEYBOARD_TOGGLE_REPLY_MODE',
};

/**
 * Robust check if a DOM element or event target is currently typeable.
 * Matches input, textarea, select, ninja-keys, contenteditable, and ProseMirror editors.
 *
 * @param {HTMLElement|EventTarget|null} target
 * @returns {boolean}
 */
export const isTargetTypeable = target => {
  if (!target) return false;
  const tagName = target.tagName ? target.tagName.toUpperCase() : '';
  if (
    tagName === 'INPUT' ||
    tagName === 'TEXTAREA' ||
    tagName === 'SELECT' ||
    tagName === 'NINJA-KEYS'
  ) {
    return true;
  }
  if (
    target.isContentEditable ||
    target.getAttribute?.('contenteditable') === 'true'
  ) {
    return true;
  }
  const className = target.className;
  if (typeof className === 'string') {
    if (
      className.includes('ProseMirror') ||
      className.includes('woot-editor') ||
      className.includes('ProseMirror-woot-style')
    ) {
      return true;
    }
  }
  if (typeof target.closest === 'function') {
    const matchingParent = target.closest(
      'input, textarea, select, ninja-keys, [contenteditable="true"], .ProseMirror, .woot-editor'
    );
    if (matchingParent) {
      return true;
    }
  }
  return false;
};

/**
 * Determines whether a keyboard event should be ignored for global shortcut dispatching.
 *
 * @param {KeyboardEvent} e
 * @param {Object|Function} handlerConfig
 * @returns {boolean}
 */
export const shouldIgnoreKeyboardEvent = (e, handlerConfig = {}) => {
  const target =
    e.target ||
    (typeof document !== 'undefined' ? document.activeElement : null);
  const isTypeable = isTargetTypeable(target) || isActiveElementTypeable(e);
  const allowOnFocusedInput =
    typeof handlerConfig === 'function'
      ? false
      : !!handlerConfig?.allowOnFocusedInput;

  if (isTypeable) {
    if (isEscape(e) && target && typeof target.blur === 'function') {
      target.blur();
    }
    return !allowOnFocusedInput;
  }
  return false;
};

/**
 * Normalizes keyboard event key/modifier combo for deterministic matching.
 *
 * @param {KeyboardEvent} e
 * @returns {string[]} candidate keys matching this event
 */
export const getEventKeyCandidates = e => {
  if (!e) return [];
  const candidates = [];
  const key = e.key;
  const code = e.code;
  const hasAlt = e.altKey;
  const hasCtrl = e.ctrlKey;
  const hasMeta = e.metaKey;
  const hasShift = e.shiftKey;

  let prefixes = [];
  if (hasMeta) {
    prefixes.push('$mod+', 'Meta+', 'Cmd+');
  }
  if (hasCtrl) {
    prefixes.push('Control+', 'Ctrl+', '$mod+');
  }
  if (hasAlt) {
    if (prefixes.length) {
      const combined = [];
      prefixes.forEach(p => {
        combined.push(`${p}Alt+`);
        combined.push(`Alt+${p}`);
      });
      prefixes = combined;
    } else {
      prefixes.push('Alt+');
    }
  }
  if (hasShift && key && key.length > 1) {
    if (prefixes.length) {
      const combined = [];
      prefixes.forEach(p => {
        combined.push(`${p}Shift+`);
        combined.push(`Shift+${p}`);
      });
      prefixes = combined;
    } else {
      prefixes.push('Shift+');
    }
  }

  if (prefixes.length) {
    prefixes.forEach(prefix => {
      if (key) {
        candidates.push(`${prefix}${key}`);
        candidates.push(`${prefix}${key.toLowerCase()}`);
        candidates.push(`${prefix}${key.toUpperCase()}`);
      }
      if (code) {
        candidates.push(`${prefix}${code}`);
      }
    });
  } else {
    // Single key presses (no modifiers)
    if (key) {
      candidates.push(key);
      candidates.push(key.toLowerCase());
      candidates.push(key.toUpperCase());
    }
    if (code) {
      candidates.push(code);
    }
    // Alias common arrow keys
    if (key === 'ArrowDown' || key === 'Down') {
      candidates.push('ArrowDown', 'Down');
    }
    if (key === 'ArrowUp' || key === 'Up') {
      candidates.push('ArrowUp', 'Up');
    }
  }

  return [...new Set(candidates)];
};

/**
 * Navigates to next or previous conversation in the active conversation list.
 *
 * @param {'next'|'previous'} direction
 * @param {Object} options
 */
export const navigateConversation = (direction = 'next', options = {}) => {
  const { onNavigate, listSelector = '.conversations-list' } = options;

  if (typeof onNavigate === 'function') {
    onNavigate(direction);
    return;
  }

  if (typeof document === 'undefined') return;

  const rootContainer = document.querySelector(listSelector) || document;
  const conversations = Array.from(
    rootContainer.querySelectorAll(
      '.conversation, [data-conversation-id], .conversations-list div.conversation'
    )
  );

  if (!conversations.length) return;

  const activeIndex = conversations.findIndex(
    el =>
      el.classList.contains('active') ||
      el.getAttribute('aria-selected') === 'true'
  );

  let targetIndex = 0;
  if (direction === 'next') {
    targetIndex =
      activeIndex >= 0 && activeIndex < conversations.length - 1
        ? activeIndex + 1
        : 0;
  } else {
    targetIndex = activeIndex > 0 ? activeIndex - 1 : conversations.length - 1;
  }

  const targetEl = conversations[targetIndex];
  if (targetEl) {
    targetEl.click?.();
    targetEl.scrollIntoView?.({ block: 'nearest', behavior: 'smooth' });
    emitter.emit(BUS_KEYBOARD_EVENTS.NAVIGATE_CONVERSATION, {
      direction,
      index: targetIndex,
      element: targetEl,
    });
  }
};

/**
 * Resolves the currently active conversation.
 *
 * @param {Object} options
 */
export const resolveConversation = (options = {}) => {
  const { onResolve, store } = options;

  if (typeof onResolve === 'function') {
    onResolve();
    return;
  }

  emitter.emit(CMD_RESOLVE_CONVERSATION);
  emitter.emit(BUS_KEYBOARD_EVENTS.RESOLVE_CONVERSATION);

  if (store && typeof store.dispatch === 'function') {
    const currentChat = store.getters?.getSelectedChat;
    if (currentChat?.id) {
      store.dispatch('toggleStatus', {
        conversationId: currentChat.id,
        status: 'resolved',
      });
    }
  }
};

/**
 * Focuses the active message composer or rich text editor.
 *
 * @param {Object} options
 */
export const focusComposer = (options = {}) => {
  const { onFocus, event } = options;
  if (event?.preventDefault) {
    event.preventDefault();
  }

  if (typeof onFocus === 'function') {
    onFocus();
    return;
  }

  emitter.emit(BUS_KEYBOARD_EVENTS.FOCUS_COMPOSER);

  if (typeof document === 'undefined') return;

  const composerEl = document.querySelector(
    '.ProseMirror, .reply-box textarea, .reply-box [contenteditable="true"], #conversation-composer, .woot-editor [contenteditable="true"]'
  );

  if (composerEl && typeof composerEl.focus === 'function') {
    composerEl.focus();
  }
};

/**
 * Opens canned responses menu or triggers fuzzy search.
 *
 * @param {Object} options
 */
export const openCannedResponsesMenu = (options = {}) => {
  const { onOpenCanned, event } = options;
  if (event?.preventDefault) {
    event.preventDefault();
  }

  if (typeof onOpenCanned === 'function') {
    onOpenCanned();
    return;
  }

  emitter.emit(BUS_KEYBOARD_EVENTS.OPEN_CANNED);
  emitter.emit('toggle-canned-menu', true);

  if (typeof document === 'undefined') return;

  const composerEl = document.querySelector(
    '.ProseMirror, .reply-box textarea, .reply-box [contenteditable="true"]'
  );
  if (composerEl && typeof composerEl.focus === 'function') {
    composerEl.focus();
  }
};

/**
 * Toggles between Public Message and Private Note modes in composer.
 *
 * @param {Object} options
 */
export const toggleNoteMode = (options = {}) => {
  const { onToggleMode, store, mode } = options;

  if (typeof onToggleMode === 'function') {
    onToggleMode();
    return;
  }

  let nextMode = mode;
  if (!nextMode && store) {
    const currentMode =
      store.getters?.['draftMessages/getReplyEditorMode'] ||
      store.getters?.getReplyEditorMode;
    nextMode =
      currentMode === REPLY_EDITOR_MODES.NOTE
        ? REPLY_EDITOR_MODES.REPLY
        : REPLY_EDITOR_MODES.NOTE;
  } else if (!nextMode) {
    nextMode = REPLY_EDITOR_MODES.NOTE;
  }

  if (store && typeof store.dispatch === 'function') {
    store.dispatch('draftMessages/setReplyEditorMode', { mode: nextMode });
  }

  emitter.emit(BUS_KEYBOARD_EVENTS.TOGGLE_REPLY_MODE, nextMode);
  emitter.emit('setReplyMode', nextMode);
};

/**
 * Global reactive composable for decoupled, reactive Inbox keyboard navigation.
 *
 * @param {Object} customOptions
 * @returns {Object}
 */
export function useKeyboardNavigation(customOptions = {}) {
  const isListening = ref(false);
  const shortcutsRegistry = reactive(new Map());
  let abortController = null;

  const registerShortcut = (keyCombo, handler, options = {}) => {
    const keys = Array.isArray(keyCombo) ? keyCombo : [keyCombo];
    keys.forEach(k => {
      shortcutsRegistry.set(k, {
        action: typeof handler === 'function' ? handler : handler.action,
        allowOnFocusedInput: Boolean(
          options.allowOnFocusedInput || handler.allowOnFocusedInput
        ),
        description: options.description || handler.description || '',
        preventDefault:
          options.preventDefault ?? handler.preventDefault ?? false,
      });
    });
  };

  const unregisterShortcut = keyCombo => {
    const keys = Array.isArray(keyCombo) ? keyCombo : [keyCombo];
    keys.forEach(k => shortcutsRegistry.delete(k));
  };

  const handleKeyDown = event => {
    if (!isListening.value) return;

    const candidates = getEventKeyCandidates(event);
    const matchedKey = candidates.find(key => {
      if (!shortcutsRegistry.has(key)) return false;
      const handlerConfig = shortcutsRegistry.get(key);
      return !shouldIgnoreKeyboardEvent(event, handlerConfig);
    });

    if (matchedKey) {
      const handlerConfig = shortcutsRegistry.get(matchedKey);
      if (handlerConfig.preventDefault && event.preventDefault) {
        event.preventDefault();
      }
      handlerConfig.action(event);
    }
  };

  const attach = () => {
    if (isListening.value) return;
    if (typeof window === 'undefined') return;

    abortController = new AbortController();
    window.addEventListener('keydown', handleKeyDown, {
      signal: abortController.signal,
    });
    isListening.value = true;
  };

  const cleanup = () => {
    if (abortController) {
      abortController.abort();
      abortController = null;
    }
    isListening.value = false;
  };

  const enable = () => {
    isListening.value = true;
  };

  const disable = () => {
    isListening.value = false;
  };

  // Setup default Inbox shortcuts
  const initDefaultShortcuts = () => {
    // J or ArrowDown -> Next conversation
    registerShortcut(INBOX_SHORTCUT_KEYS.NAVIGATE_NEXT, e => {
      navigateConversation('next', {
        onNavigate: customOptions.onNavigateNext,
        event: e,
      });
    });

    // K or ArrowUp -> Previous conversation
    registerShortcut(INBOX_SHORTCUT_KEYS.NAVIGATE_PREVIOUS, e => {
      navigateConversation('previous', {
        onNavigate: customOptions.onNavigatePrevious,
        event: e,
      });
    });

    // E -> Resolve active conversation
    registerShortcut(INBOX_SHORTCUT_KEYS.RESOLVE_CONVERSATION, e => {
      resolveConversation({
        onResolve: customOptions.onResolve,
        store: customOptions.store,
        event: e,
      });
    });

    // R -> Focus message composer
    registerShortcut(
      INBOX_SHORTCUT_KEYS.FOCUS_COMPOSER,
      e => {
        focusComposer({
          onFocus: customOptions.onFocusComposer,
          event: e,
        });
      },
      { preventDefault: true }
    );

    // / -> Open canned responses popover with fuzzy search
    registerShortcut(
      INBOX_SHORTCUT_KEYS.OPEN_CANNED,
      e => {
        openCannedResponsesMenu({
          onOpenCanned: customOptions.onOpenCanned,
          event: e,
        });
      },
      { preventDefault: true }
    );

    // Alt+P -> Toggle public message and private note
    registerShortcut(
      INBOX_SHORTCUT_KEYS.TOGGLE_NOTE_MODE,
      e => {
        toggleNoteMode({
          onToggleMode: customOptions.onToggleNoteMode,
          store: customOptions.store,
          event: e,
        });
      },
      { allowOnFocusedInput: true }
    );

    // If custom shortcuts map was passed
    if (
      customOptions.shortcuts &&
      typeof customOptions.shortcuts === 'object'
    ) {
      Object.entries(customOptions.shortcuts).forEach(([key, handler]) => {
        registerShortcut(key, handler);
      });
    }
  };

  initDefaultShortcuts();

  // Auto-attach in Vue lifecycle if within component instance
  const instance = getCurrentInstance();
  if (instance) {
    onMounted(() => {
      if (customOptions.autoAttach !== false) {
        attach();
      }
    });

    onUnmounted(() => {
      cleanup();
    });
  } else if (customOptions.autoAttach !== false) {
    attach();
  }

  const registeredShortcuts = computed(() => {
    const list = [];
    shortcutsRegistry.forEach((config, key) => {
      list.push({ key, ...config });
    });
    return list;
  });

  return {
    isListening,
    registeredShortcuts,
    shortcutsRegistry,
    registerShortcut,
    unregisterShortcut,
    enable,
    disable,
    attach,
    cleanup,
    navigateNext: () =>
      navigateConversation('next', {
        onNavigate: customOptions.onNavigateNext,
      }),
    navigatePrevious: () =>
      navigateConversation('previous', {
        onNavigate: customOptions.onNavigatePrevious,
      }),
    resolveActiveConversation: () =>
      resolveConversation({
        onResolve: customOptions.onResolve,
        store: customOptions.store,
      }),
    focusMessageComposer: () =>
      focusComposer({ onFocus: customOptions.onFocusComposer }),
    openCannedResponses: () =>
      openCannedResponsesMenu({ onOpenCanned: customOptions.onOpenCanned }),
    toggleReplyNoteMode: () =>
      toggleNoteMode({
        onToggleMode: customOptions.onToggleNoteMode,
        store: customOptions.store,
      }),
  };
}

export default useKeyboardNavigation;
