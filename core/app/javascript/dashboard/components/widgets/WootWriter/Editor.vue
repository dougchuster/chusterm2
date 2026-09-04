<script setup>
// TODO This is a huge component, we should split this up into separate composables
// like `useSignature`, `useImageHandling`, `useFileUpload`, `useSpecialContent``
import {
  ref,
  unref,
  computed,
  watch,
  onMounted,
  useTemplateRef,
  nextTick,
} from 'vue';

import CannedResponse from '../conversation/CannedResponse.vue';
import KeyboardEmojiSelector from './keyboardEmojiSelector.vue';
import TagAgents from '../conversation/TagAgents.vue';
import VariableList from '../conversation/VariableList.vue';
import TagTools from '../conversation/TagTools.vue';
import CopilotMenuBar from './CopilotMenuBar.vue';

import { useEmitter } from 'dashboard/composables/emitter';
import { useI18n } from 'vue-i18n';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useTrack } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { vOnClickOutside } from '@vueuse/components';

import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  CONVERSATION_EVENTS,
  CAPTAIN_EVENTS,
} from 'dashboard/helper/AnalyticsHelper/events';
import { MESSAGE_EDITOR_IMAGE_RESIZES } from 'dashboard/constants/editor';

import {
  messageSchema,
  buildMessageSchema,
  buildEditor,
  EditorView,
  MessageMarkdownTransformer,
  MessageMarkdownSerializer,
  EditorState,
  Selection,
} from '@ChusteRM/prosemirror-schema';
import {
  suggestionsPlugin,
  triggerCharacters,
} from '@ChusteRM/prosemirror-schema/src/mentions/plugin';

import {
  appendSignature,
  findNodeToInsertImage,
  getContentNode,
  insertAtCursor,
  removeSignature as removeSignatureHelper,
  scrollCursorIntoView,
  setURLWithQueryAndSize,
  getFormattingForEditor,
  getSelectionCoords,
  calculateMenuPosition,
  getEffectiveChannelType,
  stripUnsupportedFormatting,
} from 'dashboard/helper/editorHelper';
import {
  hasPressedEnterAndNotCmdOrShift,
  hasPressedCommandAndEnter,
} from 'shared/helpers/KeyboardHelpers';
import { createTypingIndicator } from '@ChusteRM/utils';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';
import { uploadFile } from 'dashboard/helper/uploadHelper';

const props = defineProps({
  modelValue: { type: String, default: '' },
  editorId: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  isPrivate: { type: Boolean, default: false },
  enableSuggestions: { type: Boolean, default: true },
  overrideLineBreaks: { type: Boolean, default: false },
  updateSelectionWith: { type: String, default: '' },
  enableVariables: { type: Boolean, default: false },
  enableCannedResponses: { type: Boolean, default: true },
  enableCaptainTools: { type: Boolean, default: false },
  variables: { type: Object, default: () => ({}) },
  signature: { type: String, default: '' },
  // allowSignature is a kill switch, ensuring no signature methods
  // are triggered except when this flag is true
  allowSignature: { type: Boolean, default: false },
  channelType: { type: String, default: '' },
  conversationId: { type: Number, default: null },
  medium: { type: String, default: '' },
  showImageResizeToolbar: { type: Boolean, default: false }, // A kill switch to show or hide the image toolbar
  focusOnMount: { type: Boolean, default: true },
});

const emit = defineEmits([
  'typingOn',
  'typingOff',
  'toggleUserMention',
  'toggleCannedMenu',
  'toggleVariablesMenu',
  'toggleToolsMenu',
  'clearSelection',
  'blur',
  'focus',
  'input',
  'update:modelValue',
  'executeCopilotAction',
]);

const { t } = useI18n();
const { captainTasksEnabled } = useCaptain();

const TYPING_INDICATOR_IDLE_TIME = 4000;
const MAXIMUM_FILE_UPLOAD_SIZE = 4; // in MB
const DEFAULT_FORMATTING = 'Context::Default';
const PRIVATE_NOTE_FORMATTING = 'Context::PrivateNote';

const effectiveChannelType = computed(() =>
  getEffectiveChannelType(props.channelType, props.medium)
);

const editorSchema = computed(() => {
  if (!props.channelType) return messageSchema;

  const formatType = props.isPrivate
    ? PRIVATE_NOTE_FORMATTING
    : effectiveChannelType.value;
  const formatting = getFormattingForEditor(
    formatType,
    captainTasksEnabled.value
  );
  return buildMessageSchema(formatting.marks, formatting.nodes);
});

const editorMenuOptions = computed(() => {
  const formatType = props.isPrivate
    ? PRIVATE_NOTE_FORMATTING
    : effectiveChannelType.value || DEFAULT_FORMATTING;
  const formatting = getFormattingForEditor(
    formatType,
    captainTasksEnabled.value
  );

  return formatting.menu;
});

const createState = (content, placeholder, plugins = [], methods = {}) => {
  const schema = editorSchema.value;
  // Strip unsupported formatting before parsing to prevent "Token type not supported" errors
  const sanitizedContent = stripUnsupportedFormatting(content, schema);
  return EditorState.create({
    doc: new MessageMarkdownTransformer(schema).parse(sanitizedContent),
    plugins: buildEditor({
      schema,
      placeholder,
      methods,
      plugins,
      enabledMenuOptions: editorMenuOptions.value,
    }),
  });
};

const { isEditorHotKeyEnabled, fetchSignatureFlagFromUISettings } =
  useUISettings();

const typingIndicator = createTypingIndicator(
  () => emit('typingOn'),
  () => emit('typingOff'),
  TYPING_INDICATOR_IDLE_TIME
);

// we don't need them to be reactive
// It cases weird issues where the objects are proxied
// and then the editor doesn't work as expected
// We have to wrap them in closures or use toRaw to get the actual values
let editorView = null;
let state = null;

const showUserMentions = ref(false);
const showCannedMenu = ref(false);
const showVariables = ref(false);
const showEmojiMenu = ref(false);
const showToolsMenu = ref(false);
const mentionSearchKey = ref('');
const toolSearchKey = ref('');
const cannedSearchTerm = ref('');
const variableSearchTerm = ref('');
const emojiSearchTerm = ref('');
const range = ref(null);
const isImageNodeSelected = ref(false);
const toolbarPosition = ref({ top: 0, left: 0 });
const selectedImageNode = ref(null);
const isTextSelected = ref(false); // Tracks text selection and prevents unnecessary re-renders on mouse selection
const showSelectionMenu = ref(false);
const sizes = MESSAGE_EDITOR_IMAGE_RESIZES;

// element ref
const editorRoot = useTemplateRef('editorRoot');
const imageUpload = useTemplateRef('imageUpload');
const editor = useTemplateRef('editor');

const isEditorMenuPopover = computed(
  () =>
    editorRoot.value?.classList.contains('popover-prosemirror-menu') ?? false
);

const handleCopilotAction = actionKey => {
  if (actionKey === 'improve_selection' && editorView?.state) {
    const { from, to } = editorView.state.selection;
    const selectedText = editorView.state.doc.textBetween(from, to).trim();

    if (from !== to && selectedText) {
      emit('executeCopilotAction', 'improve', selectedText);
    }
  } else {
    emit('executeCopilotAction', actionKey, props.modelValue);
  }

  showSelectionMenu.value = false;
};

const contentFromEditor = () => {
  return MessageMarkdownSerializer.serialize(editorView.state.doc);
};

const shouldShowVariables = computed(() => {
  return props.enableVariables && showVariables.value && !props.isPrivate;
});

const shouldShowCannedResponses = computed(() => {
  return props.enableCannedResponses && showCannedMenu.value;
});

function createSuggestionPlugin({
  trigger,
  minChars = 0,
  showMenu,
  searchTerm,
  isAllowed = () => true,
}) {
  return suggestionsPlugin({
    matcher: triggerCharacters(trigger, minChars),
    suggestionClass: '',
    onEnter: args => {
      if (!isAllowed()) return false;
      showMenu.value = true;
      range.value = args.range;
      editorView = args.view;
      if (searchTerm) searchTerm.value = args.text || '';
      return false;
    },
    onChange: args => {
      editorView = args.view;
      range.value = args.range;
      if (searchTerm) searchTerm.value = args.text;
      return false;
    },
    onExit: () => {
      if (searchTerm) searchTerm.value = '';
      showMenu.value = false;
      return false;
    },
    onKeyDown: ({ event }) => {
      return event.keyCode === 13 && showMenu.value;
    },
  });
}

const plugins = computed(() => {
  if (!props.enableSuggestions) {
    return [];
  }

  return [
    createSuggestionPlugin({
      trigger: '@',
      showMenu: showToolsMenu,
      searchTerm: toolSearchKey,
      isAllowed: () => props.enableCaptainTools,
    }),
    createSuggestionPlugin({
      trigger: '@',
      showMenu: showUserMentions,
      searchTerm: mentionSearchKey,
      isAllowed: () => props.isPrivate || !props.enableCaptainTools,
    }),
    createSuggestionPlugin({
      trigger: '/',
      showMenu: showCannedMenu,
      searchTerm: cannedSearchTerm,
    }),
    createSuggestionPlugin({
      trigger: '{{',
      showMenu: showVariables,
      searchTerm: variableSearchTerm,
      isAllowed: () => !props.isPrivate,
    }),
    createSuggestionPlugin({
      trigger: ':',
      minChars: 2,
      showMenu: showEmojiMenu,
      searchTerm: emojiSearchTerm,
    }),
  ];
});

const sendWithSignature = computed(() => {
  // this is considered the source of truth, we watch this property
  // on change, we toggle the signature in the editor
  if (props.allowSignature && !props.isPrivate && props.channelType) {
    return fetchSignatureFlagFromUISettings(props.channelType);
  }

  return false;
});

watch(showUserMentions, updatedValue => {
  emit('toggleUserMention', props.isPrivate && updatedValue);
});
watch(showCannedMenu, updatedValue => {
  emit('toggleCannedMenu', updatedValue);
});
watch(showVariables, updatedValue => {
  emit('toggleVariablesMenu', !props.isPrivate && updatedValue);
});
watch(showToolsMenu, updatedValue => {
  emit('toggleToolsMenu', props.enableCaptainTools && updatedValue);
});

function focusEditorInputField(pos = 'end') {
  const { tr } = editorView.state;

  const selection =
    pos === 'end' ? Selection.atEnd(tr.doc) : Selection.atStart(tr.doc);

  editorView.dispatch(tr.setSelection(selection));
  editorView.focus();
}

function isBodyEmpty(content) {
  // if content is undefined, we assume that the body is empty
  if (!content) return true;

  // if the signature is present, we need to remove it before checking
  // note that we don't update the editorView, so this is safe
  // Use effective channel type to match how signature was appended
  const bodyWithoutSignature = props.signature
    ? removeSignatureHelper(
        content,
        props.signature,
        effectiveChannelType.value
      )
    : content;

  // trimming should remove all the whitespaces, so we can check the length
  return bodyWithoutSignature.trim().length === 0;
}

function handleEmptyBodyWithSignature() {
  const { schema, tr, doc } = state;

  const isEmptyParagraph = node =>
    node && node.type === schema.nodes.paragraph && node.content.size === 0;

  // Check if empty paragraph already exists to prevent duplicates when toggling signatures
  if (isEmptyParagraph(doc.firstChild)) {
    focusEditorInputField('start');
    return;
  }

  // create a paragraph node and
  // start a transaction to append it at the end
  const paragraph = schema.nodes.paragraph.create();
  const paragraphTransaction = tr.insert(0, paragraph);
  editorView.dispatch(paragraphTransaction);

  // Set the focus at the start of the input field
  focusEditorInputField('start');
}

function focusEditor(content) {
  if (props.disabled) return;

  const unrefContent = unref(content);
  if (isBodyEmpty(unrefContent) && sendWithSignature.value) {
    // reload state can be called when switching between conversations, or when drafts is loaded
    // these drafts can also have a signature, so we need to check if the body is empty
    // and handle things accordingly
    handleEmptyBodyWithSignature();
  } else if (props.focusOnMount) {
    // this is in the else block, handleEmptyBodyWithSignature also has a call to the focus method
    // the position is set to start, because the signature is added at the end of the body
    focusEditorInputField('end');
  }
}

function openFileBrowser() {
  imageUpload.value.click();
}

function handleCopilotClick() {
  const isOpening = !showSelectionMenu.value;
  if (isOpening) {
    useTrack(CAPTAIN_EVENTS.EDITOR_AI_MENU_OPENED, {
      conversationId: props.conversationId,
      entryPoint: 'inline',
    });
  }
  showSelectionMenu.value = isOpening;
}

function handleClickOutside(event) {
  // Check if the clicked element or its parents have the ignored class
  if (event.target.closest('.ProseMirror-copilot')) return;
  showSelectionMenu.value = false;
}

function reloadState(content = props.modelValue) {
  const unrefContent = unref(content);
  state = createState(
    unrefContent,
    props.placeholder,
    plugins.value,
    { onImageUpload: openFileBrowser, onCopilotClick: handleCopilotClick },
    editorMenuOptions.value
  );

  editorView.updateState(state);
  focusEditor(unrefContent);
}

function addSignature() {
  let content = props.modelValue;
  // see if the content is empty, if it is before appending the signature
  // we need to add a paragraph node and move the cursor at the start of the editor
  const contentWasEmpty = isBodyEmpty(content);
  content = appendSignature(
    content,
    props.signature,
    effectiveChannelType.value
  );
  // need to reload first, ensuring that the editorView is updated
  reloadState(content);

  if (contentWasEmpty) {
    handleEmptyBodyWithSignature();
  }
}

function removeSignature() {
  if (!props.signature) return;
  let content = props.modelValue;
  content = removeSignatureHelper(
    content,
    props.signature,
    effectiveChannelType.value
  );
  // reload the state, ensuring that the editorView is updated
  reloadState(content);
}

function toggleSignatureInEditor(signatureEnabled) {
  // The toggleSignatureInEditor gets the new value from the
  // watcher, this means that if the value is true, the signature
  // is supposed to be added, else we remove it.
  if (signatureEnabled) {
    addSignature();
  } else {
    removeSignature();
  }
}

function setToolbarPosition() {
  const editorRect = editorRoot.value.getBoundingClientRect();
  const rect = selectedImageNode.value.getBoundingClientRect();

  toolbarPosition.value = {
    top: `${rect.top - editorRect.top - 30}px`,
    left: `${rect.left - editorRect.left - 4}px`,
  };
}

function setMenubarPosition({ selection } = {}) {
  const wrapper = editorRoot.value;
  if (!selection || !wrapper) return;
  if (!isEditorMenuPopover.value) return;

  const rect = wrapper.getBoundingClientRect();
  const isRtl = getComputedStyle(wrapper).direction === 'rtl';

  // Calculate coords and final position
  const coords = getSelectionCoords(editorView, selection, rect);
  const { left, top, width } = calculateMenuPosition(coords, rect, isRtl);

  wrapper.style.setProperty('--selection-left', `${left}px`);
  wrapper.style.setProperty(
    '--selection-right',
    `${rect.width - left - width}px`
  );
  wrapper.style.setProperty('--selection-top', `${top}px`);
}

function checkSelection(editorState) {
  showSelectionMenu.value = false;
  const hasSelection = editorState.selection.from !== editorState.selection.to;
  if (hasSelection === isTextSelected.value) return;

  isTextSelected.value = hasSelection;
  const wrapper = editorRoot.value;
  if (!wrapper) return;

  wrapper.classList.toggle('has-selection', hasSelection);
  if (hasSelection) setMenubarPosition(editorState);
}

function setURLWithQueryAndImageSize(size) {
  if (!props.showImageResizeToolbar) {
    return;
  }
  setURLWithQueryAndSize(selectedImageNode.value, size, editorView);
  isImageNodeSelected.value = false;
}

function isEditorMouseFocusedOnAnImage() {
  if (!props.showImageResizeToolbar) {
    return;
  }
  selectedImageNode.value = document.querySelector(
    'img.ProseMirror-selectednode'
  );
  if (selectedImageNode.value) {
    isImageNodeSelected.value = !!selectedImageNode.value;
    // Get the position of the selected node
    setToolbarPosition();
  } else {
    isImageNodeSelected.value = false;
  }
}

function emitOnChange() {
  emit('input', contentFromEditor());
  emit('update:modelValue', contentFromEditor());
}

function updateImgToolbarOnDelete() {
  // check if the selected node is present or not on keyup
  // this is needed because the user can select an image and then delete it
  // in that case, the selected node will be null and we need to hide the toolbar
  // otherwise, the toolbar will be visible even when the image is deleted and cause some errors
  if (selectedImageNode.value) {
    const hasImgSelectedNode = document.querySelector(
      'img.ProseMirror-selectednode'
    );
    if (!hasImgSelectedNode) {
      isImageNodeSelected.value = false;
    }
  }
}

function isEnterToSendEnabled() {
  return isEditorHotKeyEnabled('enter');
}

function isCmdPlusEnterToSendEnabled() {
  return isEditorHotKeyEnabled('cmd_enter');
}

useKeyboardEvents({
  'Alt+KeyP': {
    action: focusEditorInputField,
    allowOnFocusedInput: true,
  },
  'Alt+KeyL': {
    action: focusEditorInputField,
    allowOnFocusedInput: true,
  },
});

function onImageInsertInEditor(fileUrl) {
  const { tr } = editorView.state;

  const insertData = findNodeToInsertImage(editorView.state, fileUrl);

  if (insertData) {
    editorView.dispatch(
      tr.insert(insertData.pos, insertData.node).scrollIntoView()
    );
    focusEditorInputField();
  }
}

async function uploadImageToStorage(file) {
  try {
    const { fileUrl } = await uploadFile(file);
    if (fileUrl) {
      onImageInsertInEditor(fileUrl);
    }
    useAlert(
      t('PROFILE_SETTINGS.FORM.MESSAGE_SIGNATURE_SECTION.IMAGE_UPLOAD_SUCCESS')
    );
  } catch (error) {
    useAlert(
      t('PROFILE_SETTINGS.FORM.MESSAGE_SIGNATURE_SECTION.IMAGE_UPLOAD_ERROR')
    );
  }
}

function onFileChange() {
  const file = imageUpload.value.files[0];
  if (checkFileSizeLimit(file, MAXIMUM_FILE_UPLOAD_SIZE)) {
    uploadImageToStorage(file);
  } else {
    useAlert(
      t(
        'PROFILE_SETTINGS.FORM.MESSAGE_SIGNATURE_SECTION.IMAGE_UPLOAD_SIZE_ERROR',
        {
          size: MAXIMUM_FILE_UPLOAD_SIZE,
        }
      )
    );
  }

  imageUpload.value = '';
}

function handleLineBreakWhenEnterToSendEnabled(event) {
  if (
    hasPressedEnterAndNotCmdOrShift(event) &&
    isEnterToSendEnabled() &&
    !props.overrideLineBreaks
  ) {
    event.preventDefault();
  }
}

async function insertNodeIntoEditor(node, from = 0, to = 0) {
  state = insertAtCursor(editorView, node, from, to);
  emitOnChange();
  await nextTick();
  scrollCursorIntoView(editorView);
}

function insertContentIntoEditor(content, defaultFrom = 0) {
  const from = defaultFrom || editorView.state.selection.from || 0;
  // Use the editor's current schema to ensure compatibility with buildMessageSchema
  const currentSchema = editorView.state.schema;
  // Strip unsupported formatting before parsing to ensure content can be inserted
  // into channels that don't support certain markdown features (e.g., API channels)
  const sanitizedContent = stripUnsupportedFormatting(content, currentSchema);
  let node = new MessageMarkdownTransformer(currentSchema).parse(
    sanitizedContent
  );

  insertNodeIntoEditor(node, from, undefined);
}

/**
 * Inserts special content (mention, canned response, variable, emoji) into the editor.
 * @param {string} type - The type of special content to insert. Possible values: 'mention', 'canned_response', 'variable', 'emoji'.
 * @param {Object|string} content - The content to insert, depending on the type.
 */
function insertSpecialContent(type, content) {
  if (!editorView) {
    return;
  }

  let { node, from, to } = getContentNode(
    editorView,
    type,
    content,
    range.value,
    props.variables
  );

  if (!node) return;

  insertNodeIntoEditor(node, from, to);

  const event_map = {
    mention: CONVERSATION_EVENTS.USED_MENTIONS,
    cannedResponse: CONVERSATION_EVENTS.INSERTED_A_CANNED_RESPONSE,
    variable: CONVERSATION_EVENTS.INSERTED_A_VARIABLE,
    emoji: CONVERSATION_EVENTS.INSERTED_AN_EMOJI,
    tool: CONVERSATION_EVENTS.INSERTED_A_TOOL,
  };

  useTrack(event_map[type]);
}

function handleLineBreakWhenCmdAndEnterToSendEnabled(event) {
  if (
    hasPressedCommandAndEnter(event) &&
    isCmdPlusEnterToSendEnabled() &&
    !props.overrideLineBreaks
  ) {
    event.preventDefault();
  }
}

function onKeydown(event) {
  if (isEnterToSendEnabled()) {
    handleLineBreakWhenEnterToSendEnabled(event);
  }
  if (isCmdPlusEnterToSendEnabled()) {
    handleLineBreakWhenCmdAndEnterToSendEnabled(event);
  }
}

function createEditorView() {
  editorView = new EditorView(editor.value, {
    state: state,
    editable: () => !props.disabled,
    dispatchTransaction: tx => {
      state = state.apply(tx);
      editorView.updateState(state);
      if (tx.docChanged) {
        emitOnChange();
      }
      checkSelection(state);
    },
    handleDOMEvents: {
      keyup: () => {
        if (!props.disabled) {
          typingIndicator.start();
          updateImgToolbarOnDelete();
        }
      },
      keydown: (view, event) => !props.disabled && onKeydown(event),
      focus: () => !props.disabled && emit('focus'),
      click: () => !props.disabled && isEditorMouseFocusedOnAnImage(),
      blur: () => {
        if (props.disabled) return;
        typingIndicator.stop();
        emit('blur');
      },
      paste: (view, event) => {
        if (props.disabled) return;
        const { files } = event.clipboardData;
        if (!files.length) return;
        event.preventDefault();
        // Paste text content alongside files (e.g., spreadsheet data from Numbers app)
        // Numbers app includes invalid 0-byte attachments with text, so we paste the text here
        // while ReplyBox filters and handles valid file attachments
        const text = event.clipboardData.getData('text/plain');
        if (text) {
          view.dispatch(view.state.tr.insertText(text));
          emitOnChange();
        }
      },
    },
  });
}

watch(
  computed(() => props.modelValue),
  (newVal = '') => {
    if (newVal !== contentFromEditor()) {
      reloadState(newVal);
    }
  }
);

watch(
  computed(() => props.editorId),
  () => {
    showCannedMenu.value = false;
    showEmojiMenu.value = false;
    showVariables.value = false;
    cannedSearchTerm.value = '';
    reloadState(props.modelValue);
  }
);

watch(
  computed(() => props.isPrivate),
  () => {
    reloadState(props.modelValue);
  }
);

watch(
  computed(() => props.updateSelectionWith),
  (newValue, oldValue) => {
    if (!editorView) return;

    if (newValue !== oldValue) {
      if (props.updateSelectionWith !== '') {
        const node = editorView.state.schema.text(props.updateSelectionWith);

        const tr = editorView.state.tr.replaceSelectionWith(node);
        editorView.focus();
        state = editorView.state.apply(tr);
        editorView.updateState(state);
        emitOnChange();
        emit('clearSelection');
      }
    }
  }
);

watch(sendWithSignature, newValue => {
  // see if the allowSignature flag is true
  if (props.allowSignature) {
    toggleSignatureInEditor(newValue);
  }
});

onMounted(() => {
  // [VITE] state assignment was done in created before
  state = createState(
    props.modelValue,
    props.placeholder,
    plugins.value,
    { onImageUpload: openFileBrowser, onCopilotClick: handleCopilotClick },
    editorMenuOptions.value
  );

  createEditorView();
  editorView.updateState(state);
  if (props.focusOnMount) {
    focusEditorInputField();
  }
});

defineExpose({ focusEditorInputField });

// BUS Event to insert text or markdown into the editor at the
// current cursor position.
// Components using this
// 1. SearchPopover.vue
useEmitter(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, insertContentIntoEditor);
</script>

<template>
  <div
    ref="editorRoot"
    class="relative w-full [&_.ProseMirror-menubar-wrapper]:flex [&_.ProseMirror-menubar-wrapper]:flex-col [&_.ProseMirror-menubar-wrapper]:gap-3 [&_.ProseMirror-menubar]:relative [&_.ProseMirror-menubar]:flex [&_.ProseMirror-menubar]:!min-h-5 [&_.ProseMirror-menubar]:items-center [&_.ProseMirror-menubar]:gap-4 [&_.ProseMirror-menubar]:bg-transparent [&_.ProseMirror-menubar]:pb-0 [&_.ProseMirror-menubar]:text-ds-fg-muted ltr:[&_.ProseMirror-menubar]:-left-[3px] rtl:[&_.ProseMirror-menubar]:-right-[3px] [&_.ProseMirror-menu-active]:!bg-ds-bg-active [&_.ProseMirror-menuitem]:mr-0 [&_.ProseMirror-menuitem]:flex [&_.ProseMirror-menuitem]:size-4 [&_.ProseMirror-menuitem]:items-center [&_.ProseMirror-menuitem]:justify-center [&_.ProseMirror-icon]:flex [&_.ProseMirror-icon]:size-4 [&_.ProseMirror-icon]:flex-shrink-0 [&_.ProseMirror-icon]:items-center [&_.ProseMirror-icon]:justify-center [&_.ProseMirror-icon_svg]:size-full [&_.ProseMirror-copilot_svg]:fill-ds-accent [&_.ProseMirror-copilot_svg]:text-ds-accent [&_.ProseMirror-copilot_svg]:stroke-none [&_.ProseMirror-menubar:not(:has(*))]:!hidden [&_.ProseMirror-menubar:not(:has(*))]:!min-h-0 [&_.ProseMirror-menubar:not(:has(*))]:!max-h-none [&_.ProseMirror-menubar:not(:has(*))]:!p-0 [&_.ProseMirror-menubar-wrapper>.ProseMirror]:break-words [&_.ProseMirror-menubar-wrapper>.ProseMirror]:p-0 [&_.ProseMirror-menubar-wrapper>.ProseMirror]:text-ds-fg-default [&_.ProseMirror_h1]:text-ds-fg-default [&_.ProseMirror_h2]:text-ds-fg-default [&_.ProseMirror_h3]:text-ds-fg-default [&_.ProseMirror_h4]:text-ds-fg-default [&_.ProseMirror_h5]:text-ds-fg-default [&_.ProseMirror_h6]:text-ds-fg-default [&_.ProseMirror_p]:text-ds-fg-default [&_.ProseMirror_blockquote]:border-ds-border-strong [&_.ProseMirror_blockquote_p]:text-ds-fg-muted [&_.ProseMirror_ol_li]:list-item [&_.ProseMirror_ol_li]:list-decimal [&_.ProseMirror-woot-style]:min-h-20 [&_.ProseMirror-woot-style]:max-h-[7.5rem] [&_.ProseMirror-woot-style]:overflow-auto [&_.prosemirror-tools-node]:py-0 [&_.prosemirror-tools-node]:font-medium [&_.prosemirror-tools-node]:text-ds-fg-default [&:not(.popover-prosemirror-menu)>.copilot-editor-menu]:!top-6 rtl:[&:not(.popover-prosemirror-menu)>.copilot-editor-menu]:!left-auto rtl:[&:not(.popover-prosemirror-menu)>.copilot-editor-menu]:!right-0 [&.popover-prosemirror-menu_.ProseMirror_p:last-child]:!mb-2.5 [&.popover-prosemirror-menu_.ProseMirror-menubar]:hidden [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:absolute [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:z-50 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:!ml-0 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:!flex [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:w-fit [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:items-center [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:gap-4 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:rounded-lg [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:bg-ds-bg-elevated [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:!px-3 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:!py-1.5 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:shadow-md [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:ring-1 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:ring-ds-border-subtle [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:[top:var(--selection-top)] [&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:[left:var(--selection-left)] rtl:[&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:!left-auto rtl:[&.popover-prosemirror-menu.has-selection_.ProseMirror-menubar]:[right:var(--selection-right)] [&.popover-prosemirror-menu.has-selection_.ProseMirror-menuitem]:mr-0 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menuitem]:flex [&.popover-prosemirror-menu.has-selection_.ProseMirror-menuitem]:size-4 [&.popover-prosemirror-menu.has-selection_.ProseMirror-menuitem]:items-center [&.popover-prosemirror-menu.has-selection_.ProseMirror-icon]:flex-shrink-0 [&.popover-prosemirror-menu.has-selection_.ProseMirror-icon]:p-0.5"
    :class="{
      'pointer-events-none cursor-not-allowed opacity-50': disabled,
      '[&_.prosemirror-mention-node]:bg-ds-state-warning-soft [&_.prosemirror-mention-node]:px-1 [&_.prosemirror-mention-node]:py-0 [&_.prosemirror-mention-node]:font-medium [&_.prosemirror-mention-node]:text-ds-fg-default':
        isPrivate,
    }"
  >
    <TagAgents
      v-if="showUserMentions && isPrivate"
      :search-key="mentionSearchKey"
      @select-agent="content => insertSpecialContent('mention', content)"
    />
    <CannedResponse
      v-if="shouldShowCannedResponses"
      :search-key="cannedSearchTerm"
      @replace="content => insertSpecialContent('cannedResponse', content)"
    />
    <VariableList
      v-if="shouldShowVariables"
      :search-key="variableSearchTerm"
      @select-variable="content => insertSpecialContent('variable', content)"
    />
    <KeyboardEmojiSelector
      v-if="showEmojiMenu"
      :search-key="emojiSearchTerm"
      @select-emoji="emoji => insertSpecialContent('emoji', emoji)"
    />
    <TagTools
      v-if="showToolsMenu"
      :search-key="toolSearchKey"
      @select-tool="content => insertSpecialContent('tool', content)"
    />
    <CopilotMenuBar
      v-if="showSelectionMenu"
      v-on-click-outside="handleClickOutside"
      :has-selection="isTextSelected"
      :is-editor-menu-popover="isEditorMenuPopover"
      :editor-content="modelValue"
      :conversation-id="conversationId"
      :show-selection-menu="showSelectionMenu"
      :show-general-menu="false"
      class="copilot-editor-menu"
      @execute-copilot-action="handleCopilotAction"
    />
    <input
      ref="imageUpload"
      type="file"
      accept="image/png, image/jpeg, image/jpg, image/gif, image/webp"
      hidden
      @change="onFileChange"
    />
    <div ref="editor" />
    <div
      v-show="isImageNodeSelected && showImageResizeToolbar"
      class="absolute flex gap-1 rounded-lg bg-ds-bg-elevated p-1 text-ds-fg-default shadow-md ring-1 ring-ds-border-subtle"
      :style="{
        top: toolbarPosition.top,
        left: toolbarPosition.left,
      }"
    >
      <button
        v-for="size in sizes"
        :key="size.name"
        type="button"
        class="rounded-md px-1.5 py-0.5 text-xs font-medium ring-1 ring-ds-border-strong transition-colors hover:bg-ds-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-border-focus"
        @click="setURLWithQueryAndImageSize(size)"
      >
        {{ size.name }}
      </button>
    </div>
    <slot name="footer" />
  </div>
</template>
