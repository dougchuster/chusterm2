import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  useKeyboardNavigation,
  isTargetTypeable,
  shouldIgnoreKeyboardEvent,
  getEventKeyCandidates,
  BUS_KEYBOARD_EVENTS,
  navigateConversation,
  resolveConversation,
  focusComposer,
  openCannedResponsesMenu,
  toggleNoteMode,
} from '../useKeyboardNavigation';
import { emitter } from 'shared/helpers/mitt';
import { CMD_RESOLVE_CONVERSATION } from 'dashboard/helper/commandbar/events';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';

vi.mock('shared/helpers/mitt', () => ({
  emitter: {
    emit: vi.fn(),
    on: vi.fn(),
    off: vi.fn(),
  },
}));

describe('useKeyboardNavigation', () => {
  let nav;

  beforeEach(() => {
    vi.clearAllMocks();
    document.body.innerHTML = '';
  });

  afterEach(() => {
    if (nav?.cleanup) {
      nav.cleanup();
    }
  });

  describe('isTargetTypeable', () => {
    it('returns true for INPUT element', () => {
      const input = document.createElement('input');
      expect(isTargetTypeable(input)).toBe(true);
    });

    it('returns true for TEXTAREA element', () => {
      const textarea = document.createElement('textarea');
      expect(isTargetTypeable(textarea)).toBe(true);
    });

    it('returns true for SELECT element', () => {
      const select = document.createElement('select');
      expect(isTargetTypeable(select)).toBe(true);
    });

    it('returns true for contenteditable element', () => {
      const div = document.createElement('div');
      div.setAttribute('contenteditable', 'true');
      expect(isTargetTypeable(div)).toBe(true);
    });

    it('returns true for ProseMirror editor container', () => {
      const div = document.createElement('div');
      div.className = 'ProseMirror ProseMirror-woot-style';
      expect(isTargetTypeable(div)).toBe(true);
    });

    it('returns true for child inside a ProseMirror editor', () => {
      const editor = document.createElement('div');
      editor.className = 'ProseMirror';
      const childP = document.createElement('p');
      editor.appendChild(childP);
      document.body.appendChild(editor);

      expect(isTargetTypeable(childP)).toBe(true);
    });

    it('returns false for regular div or body', () => {
      const div = document.createElement('div');
      expect(isTargetTypeable(div)).toBe(false);
      expect(isTargetTypeable(document.body)).toBe(false);
      expect(isTargetTypeable(null)).toBe(false);
    });
  });

  describe('shouldIgnoreKeyboardEvent', () => {
    it('ignores regular shortcuts when typing in an input', () => {
      const input = document.createElement('input');
      const event = new KeyboardEvent('keydown', { key: 'j' });
      Object.defineProperty(event, 'target', { value: input });

      expect(
        shouldIgnoreKeyboardEvent(event, { allowOnFocusedInput: false })
      ).toBe(true);
    });

    it('allows shortcuts with allowOnFocusedInput when typing in an input', () => {
      const input = document.createElement('input');
      const event = new KeyboardEvent('keydown', { key: 'p', altKey: true });
      Object.defineProperty(event, 'target', { value: input });

      expect(
        shouldIgnoreKeyboardEvent(event, { allowOnFocusedInput: true })
      ).toBe(false);
    });

    it('blurs the input when Escape is pressed inside a typeable element', () => {
      const input = document.createElement('input');
      input.blur = vi.fn();
      const event = new KeyboardEvent('keydown', { key: 'Escape' });
      Object.defineProperty(event, 'target', { value: input });

      shouldIgnoreKeyboardEvent(event, { allowOnFocusedInput: false });
      expect(input.blur).toHaveBeenCalled();
    });

    it('does not ignore shortcuts when target is not typeable', () => {
      const div = document.createElement('div');
      const event = new KeyboardEvent('keydown', { key: 'j' });
      Object.defineProperty(event, 'target', { value: div });

      expect(shouldIgnoreKeyboardEvent(event, {})).toBe(false);
    });
  });

  describe('getEventKeyCandidates', () => {
    it('returns key variations for single letter key', () => {
      const event = new KeyboardEvent('keydown', { key: 'j', code: 'KeyJ' });
      const candidates = getEventKeyCandidates(event);

      expect(candidates).toContain('j');
      expect(candidates).toContain('J');
      expect(candidates).toContain('KeyJ');
    });

    it('returns key variations for arrow keys', () => {
      const downEvent = new KeyboardEvent('keydown', {
        key: 'ArrowDown',
        code: 'ArrowDown',
      });
      const candidates = getEventKeyCandidates(downEvent);

      expect(candidates).toContain('ArrowDown');
      expect(candidates).toContain('Down');
    });

    it('returns modifier key combinations', () => {
      const altPEvent = new KeyboardEvent('keydown', {
        key: 'p',
        code: 'KeyP',
        altKey: true,
      });
      const candidates = getEventKeyCandidates(altPEvent);

      expect(candidates).toContain('Alt+p');
      expect(candidates).toContain('Alt+P');
      expect(candidates).toContain('Alt+KeyP');
    });

    it('returns empty array when event is null', () => {
      expect(getEventKeyCandidates(null)).toEqual([]);
    });
  });

  describe('Keyboard navigation handlers', () => {
    describe('navigateConversation', () => {
      it('navigates to next conversation and clicks target element', () => {
        const list = document.createElement('div');
        list.className = 'conversations-list';

        const item1 = document.createElement('div');
        item1.className = 'conversation active';
        item1.click = vi.fn();
        item1.scrollIntoView = vi.fn();

        const item2 = document.createElement('div');
        item2.className = 'conversation';
        item2.click = vi.fn();
        item2.scrollIntoView = vi.fn();

        list.appendChild(item1);
        list.appendChild(item2);
        document.body.appendChild(list);

        navigateConversation('next');

        expect(item2.click).toHaveBeenCalled();
        expect(item2.scrollIntoView).toHaveBeenCalled();
        expect(emitter.emit).toHaveBeenCalledWith(
          BUS_KEYBOARD_EVENTS.NAVIGATE_CONVERSATION,
          expect.objectContaining({ direction: 'next', index: 1 })
        );
      });

      it('navigates to previous conversation and clicks target element', () => {
        const list = document.createElement('div');
        list.className = 'conversations-list';

        const item1 = document.createElement('div');
        item1.className = 'conversation';
        item1.click = vi.fn();
        item1.scrollIntoView = vi.fn();

        const item2 = document.createElement('div');
        item2.className = 'conversation active';
        item2.click = vi.fn();
        item2.scrollIntoView = vi.fn();

        list.appendChild(item1);
        list.appendChild(item2);
        document.body.appendChild(list);

        navigateConversation('previous');

        expect(item1.click).toHaveBeenCalled();
        expect(item1.scrollIntoView).toHaveBeenCalled();
        expect(emitter.emit).toHaveBeenCalledWith(
          BUS_KEYBOARD_EVENTS.NAVIGATE_CONVERSATION,
          expect.objectContaining({ direction: 'previous', index: 0 })
        );
      });

      it('calls custom onNavigate callback when provided', () => {
        const onNavigate = vi.fn();
        navigateConversation('next', { onNavigate });

        expect(onNavigate).toHaveBeenCalledWith('next');
      });
    });

    describe('resolveConversation', () => {
      it('emits CMD_RESOLVE_CONVERSATION and bus event', () => {
        resolveConversation();

        expect(emitter.emit).toHaveBeenCalledWith(CMD_RESOLVE_CONVERSATION);
        expect(emitter.emit).toHaveBeenCalledWith(
          BUS_KEYBOARD_EVENTS.RESOLVE_CONVERSATION
        );
      });

      it('dispatches store action when store is provided', () => {
        const store = {
          getters: {
            getSelectedChat: { id: 42, status: 'open' },
          },
          dispatch: vi.fn(),
        };

        resolveConversation({ store });

        expect(store.dispatch).toHaveBeenCalledWith('toggleStatus', {
          conversationId: 42,
          status: 'resolved',
        });
      });

      it('calls custom onResolve callback when provided', () => {
        const onResolve = vi.fn();
        resolveConversation({ onResolve });

        expect(onResolve).toHaveBeenCalled();
      });
    });

    describe('focusComposer', () => {
      it('emits bus event and focuses editor element in DOM', () => {
        const editor = document.createElement('div');
        editor.className = 'ProseMirror';
        editor.focus = vi.fn();
        document.body.appendChild(editor);

        const event = { preventDefault: vi.fn() };
        focusComposer({ event });

        expect(event.preventDefault).toHaveBeenCalled();
        expect(emitter.emit).toHaveBeenCalledWith(
          BUS_KEYBOARD_EVENTS.FOCUS_COMPOSER
        );
        expect(editor.focus).toHaveBeenCalled();
      });

      it('calls custom onFocus callback when provided', () => {
        const onFocus = vi.fn();
        focusComposer({ onFocus });

        expect(onFocus).toHaveBeenCalled();
      });
    });

    describe('openCannedResponsesMenu', () => {
      it('emits open canned menu bus events and focuses composer', () => {
        const editor = document.createElement('div');
        editor.className = 'ProseMirror';
        editor.focus = vi.fn();
        document.body.appendChild(editor);

        const event = { preventDefault: vi.fn() };
        openCannedResponsesMenu({ event });

        expect(event.preventDefault).toHaveBeenCalled();
        expect(emitter.emit).toHaveBeenCalledWith(
          BUS_KEYBOARD_EVENTS.OPEN_CANNED
        );
        expect(emitter.emit).toHaveBeenCalledWith('toggle-canned-menu', true);
        expect(editor.focus).toHaveBeenCalled();
      });

      it('calls custom onOpenCanned callback when provided', () => {
        const onOpenCanned = vi.fn();
        openCannedResponsesMenu({ onOpenCanned });

        expect(onOpenCanned).toHaveBeenCalled();
      });
    });

    describe('toggleNoteMode', () => {
      it('toggles mode from REPLY to NOTE in store and emits events', () => {
        const store = {
          getters: {
            'draftMessages/getReplyEditorMode': REPLY_EDITOR_MODES.REPLY,
          },
          dispatch: vi.fn(),
        };

        toggleNoteMode({ store });

        expect(store.dispatch).toHaveBeenCalledWith(
          'draftMessages/setReplyEditorMode',
          {
            mode: REPLY_EDITOR_MODES.NOTE,
          }
        );
        expect(emitter.emit).toHaveBeenCalledWith(
          BUS_KEYBOARD_EVENTS.TOGGLE_REPLY_MODE,
          REPLY_EDITOR_MODES.NOTE
        );
      });

      it('toggles mode from NOTE to REPLY in store', () => {
        const store = {
          getters: {
            'draftMessages/getReplyEditorMode': REPLY_EDITOR_MODES.NOTE,
          },
          dispatch: vi.fn(),
        };

        toggleNoteMode({ store });

        expect(store.dispatch).toHaveBeenCalledWith(
          'draftMessages/setReplyEditorMode',
          {
            mode: REPLY_EDITOR_MODES.REPLY,
          }
        );
      });

      it('calls custom onToggleMode callback when provided', () => {
        const onToggleMode = vi.fn();
        toggleNoteMode({ onToggleMode });

        expect(onToggleMode).toHaveBeenCalled();
      });
    });
  });

  describe('useKeyboardNavigation composable instance', () => {
    it('registers all default Inbox shortcuts', () => {
      nav = useKeyboardNavigation({ autoAttach: false });

      expect(nav.isListening.value).toBe(false);
      expect(nav.registeredShortcuts.value.length).toBeGreaterThan(0);

      const registeredKeys = nav.registeredShortcuts.value.map(s => s.key);
      expect(registeredKeys).toContain('j');
      expect(registeredKeys).toContain('k');
      expect(registeredKeys).toContain('e');
      expect(registeredKeys).toContain('r');
      expect(registeredKeys).toContain('/');
      expect(registeredKeys).toContain('Alt+P');
    });

    it('attaches listener on window and handles keydown events', () => {
      const onResolve = vi.fn();
      nav = useKeyboardNavigation({
        onResolve,
        autoAttach: true,
      });

      expect(nav.isListening.value).toBe(true);

      const event = new KeyboardEvent('keydown', { key: 'e', code: 'KeyE' });
      window.dispatchEvent(event);

      expect(onResolve).toHaveBeenCalled();
    });

    it('does not dispatch shortcuts when disabled', () => {
      const onResolve = vi.fn();
      nav = useKeyboardNavigation({
        onResolve,
        autoAttach: true,
      });

      nav.disable();
      expect(nav.isListening.value).toBe(false);

      const event = new KeyboardEvent('keydown', { key: 'e', code: 'KeyE' });
      window.dispatchEvent(event);

      expect(onResolve).not.toHaveBeenCalled();

      nav.enable();
      expect(nav.isListening.value).toBe(true);

      window.dispatchEvent(event);
      expect(onResolve).toHaveBeenCalled();
    });

    it('ignores shortcut when user is typing inside an input element', () => {
      const onNavigateNext = vi.fn();
      nav = useKeyboardNavigation({
        onNavigateNext,
        autoAttach: true,
      });

      const input = document.createElement('input');
      document.body.appendChild(input);

      const event = new KeyboardEvent('keydown', {
        key: 'j',
        bubbles: true,
      });
      Object.defineProperty(event, 'target', { value: input });

      window.dispatchEvent(event);

      expect(onNavigateNext).not.toHaveBeenCalled();
    });

    it('allows Alt+P shortcut even when focused in an input element', () => {
      const onToggleNoteMode = vi.fn();
      nav = useKeyboardNavigation({
        onToggleNoteMode,
        autoAttach: true,
      });

      const input = document.createElement('input');
      document.body.appendChild(input);

      const event = new KeyboardEvent('keydown', {
        key: 'p',
        code: 'KeyP',
        altKey: true,
        bubbles: true,
      });
      Object.defineProperty(event, 'target', { value: input });

      window.dispatchEvent(event);

      expect(onToggleNoteMode).toHaveBeenCalled();
    });

    it('supports dynamic registerShortcut and unregisterShortcut', () => {
      const customAction = vi.fn();
      nav = useKeyboardNavigation({ autoAttach: true });

      nav.registerShortcut('Ctrl+z', customAction);
      const event = new KeyboardEvent('keydown', {
        key: 'z',
        code: 'KeyZ',
        ctrlKey: true,
      });

      window.dispatchEvent(event);
      expect(customAction).toHaveBeenCalled();

      nav.unregisterShortcut('Ctrl+z');
      customAction.mockClear();

      window.dispatchEvent(event);
      expect(customAction).not.toHaveBeenCalled();
    });

    it('exposes imperative action methods', () => {
      const onNavigateNext = vi.fn();
      const onNavigatePrevious = vi.fn();
      const onResolve = vi.fn();
      const onFocusComposer = vi.fn();
      const onOpenCanned = vi.fn();
      const onToggleNoteMode = vi.fn();

      nav = useKeyboardNavigation({
        onNavigateNext,
        onNavigatePrevious,
        onResolve,
        onFocusComposer,
        onOpenCanned,
        onToggleNoteMode,
        autoAttach: false,
      });

      nav.navigateNext();
      expect(onNavigateNext).toHaveBeenCalledWith('next');

      nav.navigatePrevious();
      expect(onNavigatePrevious).toHaveBeenCalledWith('previous');

      nav.resolveActiveConversation();
      expect(onResolve).toHaveBeenCalled();

      nav.focusMessageComposer();
      expect(onFocusComposer).toHaveBeenCalled();

      nav.openCannedResponses();
      expect(onOpenCanned).toHaveBeenCalled();

      nav.toggleReplyNoteMode();
      expect(onToggleNoteMode).toHaveBeenCalled();
    });
  });
});
