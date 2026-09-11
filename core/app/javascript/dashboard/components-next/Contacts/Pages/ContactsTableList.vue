<script setup>
import { computed } from 'vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  contacts: { type: Array, required: true },
  selectedContactIds: {
    type: Array,
    default: () => [],
  },
  categoryLabels: {
    type: Array,
    default: () => [],
  },
  agents: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['toggleContact', 'toggleAll', 'showContact']);

const tableText = {
  name: 'Nome',
  relationship: 'Relacionamento',
  lifecycle: 'Etapa',
  categories: 'Categorias',
  owner: 'Responsável',
  company: 'Empresa',
  phone: 'Telefone',
  email: 'E-mail',
  empty: '-',
};

const relationshipLabels = {
  lead: 'Lead',
  customer: 'Cliente',
};

const lifecycleLabels = {
  visitor: 'Visitante',
  lead: 'Lead',
  qualified_lead: 'Lead qualificado',
  lead_qualified: 'Lead qualificado',
  triage: 'Triagem',
  in_triage: 'Triagem',
  consultation_scheduled: 'Consulta agendada',
  customer: 'Cliente',
  active_customer: 'Cliente ativo',
  recurring_customer: 'Cliente recorrente',
  recurring: 'Cliente recorrente',
  ex_customer: 'Ex-cliente',
  lost: 'Perdido',
};

const selectedIdsSet = computed(() => new Set(props.selectedContactIds || []));
const visibleContactIds = computed(() =>
  props.contacts.map(contact => contact.id)
);
const allVisibleSelected = computed(
  () =>
    visibleContactIds.value.length > 0 &&
    visibleContactIds.value.every(id => selectedIdsSet.value.has(id))
);
const hasPartialSelection = computed(
  () =>
    visibleContactIds.value.some(id => selectedIdsSet.value.has(id)) &&
    !allVisibleSelected.value
);
const categoryLookup = computed(() => {
  return props.categoryLabels.reduce((result, label) => {
    if (label?.title) result[label.title] = label;
    return result;
  }, {});
});
const categoryTitleSet = computed(
  () => new Set(Object.keys(categoryLookup.value))
);

const fieldValue = (contact, camelKey, snakeKey) =>
  contact?.[camelKey] ??
  contact?.[snakeKey] ??
  contact?.additionalAttributes?.[camelKey] ??
  contact?.additionalAttributes?.[snakeKey] ??
  '';

const companyName = contact =>
  contact.additionalAttributes?.companyName ||
  contact.additionalAttributes?.company_name ||
  contact.additionalAttributes?.company ||
  '';
const contactPhoneNumber = contact =>
  fieldValue(contact, 'phoneNumber', 'phone_number');

const humanize = value =>
  value
    ?.toString()
    .replace(
      /^(area|origin|location|campaign|custom|status|restriction|rel|temp|risk|doc)[._]/,
      ''
    )
    .replace(/_/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase()) || value;

const relationshipStatus = contact =>
  fieldValue(contact, 'relationshipStatus', 'relationship_status');

const lifecycleStage = contact =>
  fieldValue(contact, 'lifecycleStage', 'lifecycle_stage');

const crmOwnerId = contact => fieldValue(contact, 'crmOwnerId', 'crm_owner_id');

const relationshipLabel = contact =>
  relationshipLabels[relationshipStatus(contact)] || tableText.empty;

const lifecycleLabel = contact =>
  lifecycleLabels[lifecycleStage(contact)] ||
  humanize(lifecycleStage(contact)) ||
  tableText.empty;

const ownerName = contact => {
  const owner = contact.crmOwner || contact.crm_owner;
  const directName =
    owner?.availableName ||
    owner?.available_name ||
    owner?.name ||
    owner?.email ||
    '';
  if (directName) return directName;

  const ownerId = crmOwnerId(contact);
  const agent = props.agents.find(item => String(item.id) === String(ownerId));
  return agent?.name || agent?.email || '';
};

const contactLabelTitles = contact => {
  const labels =
    contact.labels ||
    contact.labelList ||
    contact.label_list ||
    contact.cachedLabelList ||
    contact.cached_label_list ||
    [];
  const normalizedLabels = Array.isArray(labels)
    ? labels
    : labels
        .toString()
        .split(',')
        .map(label => label.trim())
        .filter(Boolean);

  if (!categoryTitleSet.value.size) return normalizedLabels;
  return normalizedLabels.filter(label => categoryTitleSet.value.has(label));
};

const visibleContactLabels = contact => contactLabelTitles(contact).slice(0, 2);

const hiddenLabelsCount = contact =>
  Math.max(
    contactLabelTitles(contact).length - visibleContactLabels(contact).length,
    0
  );

const categoryDisplayName = title =>
  categoryLookup.value[title]?.display_title || humanize(title);

const categoryColor = title => categoryLookup.value[title]?.color || '#64748b';

const phoneLink = phoneNumber =>
  phoneNumber ? `tel:${phoneNumber.toString().replace(/[^\d+]/g, '')}` : '';

const onToggleContact = (contact, event) => {
  emit('toggleContact', { id: contact.id, value: event.target.checked });
};

const onToggleAll = event => {
  emit('toggleAll', event.target.checked);
};
</script>

<template>
  <div class="overflow-hidden rounded-lg border border-n-weak bg-n-surface-1">
    <div class="overflow-x-auto">
      <table class="min-w-[1180px] border-collapse text-sm">
        <thead class="bg-n-solid-2 text-[11px] uppercase text-n-slate-10">
          <tr>
            <th class="w-12 border-b border-r border-n-weak px-4 py-3">
              <Checkbox
                :model-value="allVisibleSelected"
                :indeterminate="hasPartialSelection"
                @change="onToggleAll"
              />
            </th>
            <th
              class="min-w-64 border-b border-r border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.name }}
            </th>
            <th
              class="min-w-36 border-b border-r border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.relationship }}
            </th>
            <th
              class="min-w-44 border-b border-r border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.lifecycle }}
            </th>
            <th
              class="min-w-56 border-b border-r border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.categories }}
            </th>
            <th
              class="min-w-48 border-b border-r border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.owner }}
            </th>
            <th
              class="min-w-52 border-b border-r border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.company }}
            </th>
            <th
              class="min-w-52 border-b border-r border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.phone }}
            </th>
            <th
              class="min-w-64 border-b border-n-weak px-3 py-3 text-left font-semibold"
            >
              {{ tableText.email }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="contact in contacts"
            :key="contact.id"
            class="border-b border-n-weak text-n-slate-11 last:border-b-0 hover:bg-n-slate-2"
            :class="{ 'bg-n-slate-2': selectedIdsSet.has(contact.id) }"
          >
            <td class="border-r border-n-weak px-4 py-2">
              <Checkbox
                :model-value="selectedIdsSet.has(contact.id)"
                @change="event => onToggleContact(contact, event)"
              />
            </td>
            <td class="border-r border-n-weak px-3 py-2">
              <button
                type="button"
                class="max-w-80 truncate text-left font-medium text-n-blue-11 hover:underline"
                :title="contact.name || tableText.empty"
                @click="emit('showContact', contact.id)"
              >
                {{ contact.name || tableText.empty }}
              </button>
            </td>
            <td class="border-r border-n-weak px-3 py-2">
              <span
                class="inline-flex h-7 items-center rounded-full px-2.5 text-xs font-semibold"
                :class="
                  relationshipStatus(contact) === 'customer'
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : relationshipStatus(contact) === 'lead'
                      ? 'bg-n-blue-3 text-n-blue-11'
                      : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{ relationshipLabel(contact) }}
              </span>
            </td>
            <td class="border-r border-n-weak px-3 py-2">
              <span
                class="block max-w-40 truncate"
                :title="lifecycleLabel(contact)"
              >
                {{ lifecycleLabel(contact) }}
              </span>
            </td>
            <td class="border-r border-n-weak px-3 py-2">
              <div
                v-if="contactLabelTitles(contact).length"
                class="flex max-w-56 flex-wrap gap-1"
              >
                <span
                  v-for="label in visibleContactLabels(contact)"
                  :key="label"
                  class="inline-flex h-6 max-w-32 items-center rounded-full border px-2 text-[11px] font-medium"
                  :style="{
                    borderColor: categoryColor(label),
                    backgroundColor: `${categoryColor(label)}14`,
                    color: categoryColor(label),
                  }"
                  :title="categoryDisplayName(label)"
                >
                  <span class="truncate">{{ categoryDisplayName(label) }}</span>
                </span>
                <span
                  v-if="hiddenLabelsCount(contact)"
                  class="inline-flex h-6 items-center rounded-full bg-n-slate-3 px-2 text-[11px] font-medium text-n-slate-11"
                >
                  {{ `+${hiddenLabelsCount(contact)}` }}
                </span>
              </div>
              <span v-else>{{ tableText.empty }}</span>
            </td>
            <td class="border-r border-n-weak px-3 py-2">
              <span class="block max-w-44 truncate" :title="ownerName(contact)">
                {{ ownerName(contact) || tableText.empty }}
              </span>
            </td>
            <td class="border-r border-n-weak px-3 py-2">
              <span
                class="block max-w-72 truncate"
                :title="companyName(contact)"
              >
                {{ companyName(contact) || tableText.empty }}
              </span>
            </td>
            <td class="border-r border-n-weak px-3 py-2">
              <a
                v-if="contactPhoneNumber(contact)"
                :href="phoneLink(contactPhoneNumber(contact))"
                class="text-n-blue-11 hover:underline"
              >
                {{ contactPhoneNumber(contact) }}
              </a>
              <span v-else>{{ tableText.empty }}</span>
            </td>
            <td class="px-3 py-2">
              <a
                v-if="contact.email"
                :href="`mailto:${contact.email}`"
                class="block max-w-80 truncate text-n-blue-11 hover:underline"
                :title="contact.email"
              >
                {{ contact.email }}
              </a>
              <span v-else>{{ tableText.empty }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
