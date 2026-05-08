<script setup>
import { computed, watch, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import LabelItem from 'dashboard/components-next/label/LabelItem.vue';
import AddLabel from 'dashboard/components-next/label/AddLabel.vue';

const props = defineProps({
  contactId: {
    type: [String, Number],
    default: null,
  },
});

const store = useStore();
const route = useRoute();

const showDropdown = ref(false);

// Store the currently hovered label's ID
// Using JS state management instead of CSS :hover / group hover
// This will solve the flickering issue when hovering over the last label item
const hoveredLabel = ref(null);

const allLabels = useMapGetter('labels/getLabels');
const contactLabels = useMapGetter('contactLabels/getContactLabels');
const contactConversations = useMapGetter(
  'contactConversations/getAllConversationsByContactId'
);

const contactLabelTitles = computed(() => contactLabels.value(props.contactId));

const conversationLabelTitles = computed(() => {
  const conversations = contactConversations.value(props.contactId) || [];
  return [
    ...new Set(
      conversations.flatMap(conversation => conversation.labels || [])
    ),
  ];
});

const linkedLabelTitles = computed(() => [
  ...new Set([...contactLabelTitles.value, ...conversationLabelTitles.value]),
]);

const savedLabels = computed(() => {
  return allLabels.value.filter(({ title }) =>
    linkedLabelTitles.value.includes(title)
  );
});

const labelMenuItems = computed(() => {
  return allLabels.value
    ?.map(label => ({
      label: label.display_title || label.title,
      value: label.id,
      thumbnail: {
        name: label.display_title || label.title,
        color: label.color,
      },
      isSelected: savedLabels.value.some(
        savedLabel => savedLabel.id === label.id
      ),
      action: 'contactLabel',
    }))
    .toSorted((a, b) => Number(a.isSelected) - Number(b.isSelected));
});

const fetchLabels = async contactId => {
  if (!contactId) {
    return;
  }
  if (!allLabels.value.length) {
    await store.dispatch('labels/get');
  }
  await Promise.all([
    store.dispatch('contactLabels/get', contactId),
    store.dispatch('contactConversations/get', contactId),
  ]);

  const labelsToSync = conversationLabelTitles.value.filter(
    title => !contactLabelTitles.value.includes(title)
  );

  if (labelsToSync.length) {
    await store.dispatch('contactLabels/update', {
      contactId,
      labels: [...new Set([...contactLabelTitles.value, ...labelsToSync])],
    });
  }
};

const handleLabelAction = async ({ value }) => {
  try {
    // Get current label titles
    const currentLabels = contactLabelTitles.value;

    // Find the label title for the ID (value)
    const selectedLabel = allLabels.value.find(label => label.id === value);
    if (!selectedLabel) return;

    let updatedLabels;

    // If label is already selected, remove it (toggle behavior)
    if (currentLabels.includes(selectedLabel.title)) {
      updatedLabels = currentLabels.filter(
        labelTitle => labelTitle !== selectedLabel.title
      );
    } else {
      // Add the new label
      updatedLabels = [...currentLabels, selectedLabel.title];
    }

    await store.dispatch('contactLabels/update', {
      contactId: props.contactId,
      labels: updatedLabels,
    });

    showDropdown.value = false;
  } catch (error) {
    // error
  }
};

const handleRemoveLabel = label => {
  return handleLabelAction({ value: label.id });
};

watch(
  () => props.contactId,
  (newVal, oldVal) => {
    if (newVal !== oldVal) {
      fetchLabels(newVal);
    }
  }
);
onMounted(() => {
  fetchLabels(props.contactId || route.params.contactId);
});

const handleMouseLeave = () => {
  // Reset hover state when mouse leaves the container
  // This ensures all labels return to their default state
  hoveredLabel.value = null;
};

const handleLabelHover = labelId => {
  // Added this to prevent flickering on when showing remove button on hover
  // If the label item is at end of the line, it will show the remove button
  // when hovering over the last label item
  hoveredLabel.value = labelId;
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2" @mouseleave="handleMouseLeave">
    <LabelItem
      v-for="label in savedLabels"
      :key="label.id"
      :label="label"
      :is-hovered="hoveredLabel === label.id"
      @remove="handleRemoveLabel"
      @hover="handleLabelHover(label.id)"
    />
    <AddLabel
      :label-menu-items="labelMenuItems"
      @update-label="handleLabelAction"
    />
  </div>
</template>
