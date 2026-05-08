import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useOperators } from './operators';
import { useMapGetter } from 'dashboard/composables/store.js';
import {
  buildAttributesFilterTypes,
  CONTACT_ATTRIBUTES,
} from './helper/filterHelper.js';
import countries from 'shared/constants/countries.js';

/**
 * @typedef {Object} FilterOption
 * @property {string|number} id
 * @property {string} name
 * @property {import('vue').VNode} [icon]
 */

/**
 * @typedef {Object} FilterOperator
 * @property {string} value
 * @property {string} label
 * @property {string} icon
 * @property {boolean} hasInput
 */

/**
 * @typedef {Object} FilterType
 * @property {string} attributeKey - The attribute key
 * @property {string} value - This is a proxy for the attribute key used in FilterSelect
 * @property {string} attributeName - The attribute name used to display on the UI
 * @property {string} label - This is a proxy for the attribute name used in FilterSelect
 * @property {'multiSelect'|'searchSelect'|'plainText'|'date'|'booleanSelect'} inputType - The input type for the attribute
 * @property {FilterOption[]} [options] - The options available for the attribute if it is a multiSelect or singleSelect type
 * @property {'text'|'number'} dataType
 * @property {FilterOperator[]} filterOperators - The operators available for the attribute
 * @property {'standard'|'additional'|'customAttributes'} attributeModel
 */

/**
 * @typedef {Object} FilterGroup
 * @property {string} name
 * @property {FilterType[]} attributes
 */

/**
 * Composable that provides conversation filtering context
 * @returns {{ filterTypes: import('vue').ComputedRef<FilterType[]>, filterGroups: import('vue').ComputedRef<FilterGroup[]> }}
 */
export function useContactFilterContext() {
  const { t } = useI18n();

  const contactAttributes = useMapGetter('attributes/getContactAttributes');
  const labels = useMapGetter('labels/getLabels');
  const agents = useMapGetter('agents/getVerifiedAgents');

  const {
    operators,
    equalityOperators,
    presenceOperators,
    containmentOperators,
    dateOperators,
    getOperatorTypes,
  } = useOperators();

  const textPresenceOperators = computed(() => [
    ...containmentOperators.value,
    operators.value.is_present,
    operators.value.is_not_present,
  ]);

  /**
   * @type {import('vue').ComputedRef<FilterType[]>}
   */
  const customFilterTypes = computed(() =>
    buildAttributesFilterTypes(
      contactAttributes.value,
      getOperatorTypes,
      'contact'
    )
  );

  /**
   * @type {import('vue').ComputedRef<FilterType[]>}
   */
  const filterTypes = computed(() => [
    {
      attributeKey: CONTACT_ATTRIBUTES.NAME,
      value: CONTACT_ATTRIBUTES.NAME,
      attributeName: t('CONTACTS_LAYOUT.FILTER.NAME'),
      label: t('CONTACTS_LAYOUT.FILTER.NAME'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.EMAIL,
      value: CONTACT_ATTRIBUTES.EMAIL,
      attributeName: t('CONTACTS_LAYOUT.FILTER.EMAIL'),
      label: t('CONTACTS_LAYOUT.FILTER.EMAIL'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.PHONE_NUMBER,
      value: CONTACT_ATTRIBUTES.PHONE_NUMBER,
      attributeName: t('CONTACTS_LAYOUT.FILTER.PHONE_NUMBER'),
      label: t('CONTACTS_LAYOUT.FILTER.PHONE_NUMBER'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.IDENTIFIER,
      value: CONTACT_ATTRIBUTES.IDENTIFIER,
      attributeName: t('CONTACTS_LAYOUT.FILTER.IDENTIFIER'),
      label: t('CONTACTS_LAYOUT.FILTER.IDENTIFIER'),
      inputType: 'plainText',
      dataType: 'number',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.COUNTRY_CODE,
      value: CONTACT_ATTRIBUTES.COUNTRY_CODE,
      attributeName: t('FILTER.ATTRIBUTES.COUNTRY_NAME'),
      label: t('FILTER.ATTRIBUTES.COUNTRY_NAME'),
      inputType: 'searchSelect',
      options: countries,
      dataType: 'number',
      filterOperators: equalityOperators.value,
      attributeModel: 'additional',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.CITY,
      value: CONTACT_ATTRIBUTES.CITY,
      attributeName: t('CONTACTS_LAYOUT.FILTER.CITY'),
      label: t('CONTACTS_LAYOUT.FILTER.CITY'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.CREATED_AT,
      value: CONTACT_ATTRIBUTES.CREATED_AT,
      attributeName: t('CONTACTS_LAYOUT.FILTER.CREATED_AT'),
      label: t('CONTACTS_LAYOUT.FILTER.CREATED_AT'),
      inputType: 'date',
      dataType: 'text',
      filterOperators: dateOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.LAST_ACTIVITY_AT,
      value: CONTACT_ATTRIBUTES.LAST_ACTIVITY_AT,
      attributeName: t('CONTACTS_LAYOUT.FILTER.LAST_ACTIVITY'),
      label: t('CONTACTS_LAYOUT.FILTER.LAST_ACTIVITY'),
      inputType: 'date',
      dataType: 'text',
      filterOperators: dateOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.REFERER,
      value: CONTACT_ATTRIBUTES.REFERER,
      attributeName: t('CONTACTS_LAYOUT.FILTER.REFERER_LINK'),
      label: t('CONTACTS_LAYOUT.FILTER.REFERER_LINK'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.BLOCKED,
      value: CONTACT_ATTRIBUTES.BLOCKED,
      attributeName: t('CONTACTS_LAYOUT.FILTER.BLOCKED'),
      label: t('CONTACTS_LAYOUT.FILTER.BLOCKED'),
      inputType: 'searchSelect',
      options: [
        {
          id: 'true',
          name: t('CONTACTS_LAYOUT.FILTER.BLOCKED_TRUE'),
        },
        {
          id: 'false',
          name: t('CONTACTS_LAYOUT.FILTER.BLOCKED_FALSE'),
        },
      ],
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.LABELS,
      value: CONTACT_ATTRIBUTES.LABELS,
      attributeName: t('CONTACTS_FILTER.ATTRIBUTES.LABELS'),
      label: t('CONTACTS_FILTER.ATTRIBUTES.LABELS'),
      inputType: 'multiSelect',
      options: labels.value?.map(label => ({
        id: label.title,
        name: label.display_title || label.title,
      })),
      dataType: 'text',
      filterOperators: presenceOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.RELATIONSHIP_STATUS,
      value: CONTACT_ATTRIBUTES.RELATIONSHIP_STATUS,
      attributeName: 'Lead/Cliente',
      label: 'Lead/Cliente',
      inputType: 'searchSelect',
      options: [
        { id: 'lead', name: 'Lead' },
        { id: 'customer', name: 'Cliente' },
      ],
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.LIFECYCLE_STAGE,
      value: CONTACT_ATTRIBUTES.LIFECYCLE_STAGE,
      attributeName: 'Etapa CRM',
      label: 'Etapa CRM',
      inputType: 'searchSelect',
      options: [
        { id: 'lead', name: 'Lead' },
        { id: 'qualified_lead', name: 'Lead qualificado' },
        { id: 'triage', name: 'Triagem' },
        { id: 'consultation_scheduled', name: 'Consulta agendada' },
        { id: 'customer', name: 'Cliente' },
        { id: 'active_customer', name: 'Cliente ativo' },
        { id: 'recurring_customer', name: 'Cliente recorrente' },
        { id: 'lost', name: 'Perdido' },
      ],
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.CRM_OWNER_ID,
      value: CONTACT_ATTRIBUTES.CRM_OWNER_ID,
      attributeName: 'Responsável CRM',
      label: 'Responsável CRM',
      inputType: 'searchSelect',
      options:
        agents.value?.map(agent => ({
          id: agent.id,
          name: agent.name || agent.email,
        })) || [],
      dataType: 'number',
      filterOperators: presenceOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.SOURCE_LIST,
      value: CONTACT_ATTRIBUTES.SOURCE_LIST,
      attributeName: 'Lista de origem',
      label: 'Lista de origem',
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: textPresenceOperators.value,
      attributeModel: 'additional',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.LEGAL_AREA,
      value: CONTACT_ATTRIBUTES.LEGAL_AREA,
      attributeName: 'Setor jurídico',
      label: 'Setor jurídico',
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: textPresenceOperators.value,
      attributeModel: 'additional',
    },
    ...customFilterTypes.value,
  ]);

  return { filterTypes };
}
