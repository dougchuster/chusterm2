import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import { useLocale } from 'shared/composables/useLocale';
import { ICON_CONTACT, ICON_DEAL } from 'dashboard/helper/commandbar/icons';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export const normalizeText = text =>
  (text || '')
    .toString()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

export const extractInitials = str => {
  if (!str || typeof str !== 'string') return '';
  return str
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w[0])
    .join('')
    .toLowerCase();
};

export const formatCurrency = (val, currency = 'BRL', locale = 'pt-BR') => {
  if (val === null || val === undefined || Number.isNaN(Number(val))) return '';
  try {
    return new Intl.NumberFormat(locale || 'pt-BR', {
      style: 'currency',
      currency: currency || 'BRL',
      maximumFractionDigits: 0,
    }).format(Number(val));
  } catch (e) {
    return `${currency || 'R$'} ${val}`;
  }
};

export const buildContactAction = ({
  contact,
  accountId,
  t,
  isRecent = false,
  router,
}) => {
  const name = contact.name || '';
  const email = contact.email || '';
  const phone = contact.phone_number || '';
  const company = contact.company_name || '';
  const subtitle = [company, email, phone].filter(Boolean).join(' �?� ');

  const title = subtitle
    ? `${name || `#${contact.id}`} (${subtitle})`
    : name || email || phone || `#${contact.id}`;

  const section = isRecent
    ? t('COMMAND_BAR.SECTIONS.RECENT_CONTACTS')
    : t('COMMAND_BAR.SECTIONS.CONTACTS');

  const nameNorm = normalizeText(name);
  const companyNorm = normalizeText(company);
  const initials = extractInitials(name);

  const keywords = [
    name,
    nameNorm,
    email,
    phone,
    company,
    companyNorm,
    initials,
    '@contact',
    '@contato',
    '@cliente',
    '@lead',
    '@pessoa',
    'contact',
    'contato',
    'cliente',
    'lead',
    'pessoa',
  ]
    .filter(Boolean)
    .join(' ');

  return {
    id: `${isRecent ? 'recent' : 'dynamic'}_contact_${contact.id}`,
    title,
    section,
    icon: ICON_CONTACT,
    keywords,
    handler: () => {
      router.push(frontendURL(`accounts/${accountId}/contacts/${contact.id}`));
    },
  };
};

export const buildDealAction = ({
  deal,
  accountId,
  t,
  isRecent = false,
  router,
  locale = 'pt-BR',
}) => {
  const stageName = deal.stage?.name || deal.crm_pipeline_stage?.name || '';
  const stageNorm = normalizeText(stageName);
  const formattedVal = deal.value
    ? formatCurrency(deal.value, deal.currency, locale)
    : '';
  const rawVal = deal.value ? String(deal.value) : '';
  const contactName = deal.contact?.name || '';
  const companyName = deal.company?.name || '';
  const titleText = deal.title || deal.name || `#${deal.id}`;
  const titleNorm = normalizeText(titleText);
  const initials = extractInitials(titleText);

  const contextSubtitle = [formattedVal, stageName, contactName || companyName]
    .filter(Boolean)
    .join(' �?� ');

  const title = contextSubtitle
    ? `${titleText} (${contextSubtitle})`
    : titleText;

  const section = isRecent
    ? t('COMMAND_BAR.SECTIONS.RECENT_DEALS')
    : t('COMMAND_BAR.SECTIONS.DEALS');

  const keywords = [
    titleText,
    titleNorm,
    stageName,
    stageNorm,
    contactName,
    normalizeText(contactName),
    companyName,
    normalizeText(companyName),
    rawVal,
    formattedVal,
    initials,
    '#deal',
    '#negocio',
    '#oportunidade',
    '#venda',
    '#funil',
    '#pipeline',
    '$deal',
    'deal',
    'negócio',
    'negocio',
    'funil',
    'pipeline',
    'oportunidade',
    'venda',
  ]
    .filter(Boolean)
    .join(' ');

  return {
    id: `${isRecent ? 'recent' : 'dynamic'}_deal_${deal.id}`,
    title,
    section,
    icon: ICON_DEAL,
    keywords,
    handler: () => {
      router.push(frontendURL(`accounts/${accountId}/crm/deals/${deal.id}`));
    },
  };
};

export function useCrmCommandHotKeys() {
  const { t } = useI18n();
  const router = useRouter();
  const { resolvedLocale } = useLocale();

  const currentAccountId = useMapGetter('getCurrentAccountId');
  const isFeatureEnabledOnAccount = useMapGetter(
    'accounts/isFeatureEnabledonAccount'
  );
  const storeContacts = useMapGetter('contacts/getContacts');
  const storeDeals = useMapGetter('crm/getDeals');

  const crmRecentHotKeys = computed(() => {
    const isCrmEnabled = isFeatureEnabledOnAccount.value?.(
      currentAccountId.value,
      FEATURE_FLAGS.CRM
    );

    const contactList = Array.isArray(storeContacts.value)
      ? storeContacts.value
      : [];
    const dealList = Array.isArray(storeDeals.value) ? storeDeals.value : [];

    const contactActions = contactList.slice(0, 4).map(contact =>
      buildContactAction({
        contact,
        accountId: currentAccountId.value,
        t,
        isRecent: true,
        router,
      })
    );

    const dealActions = isCrmEnabled
      ? dealList.slice(0, 4).map(deal =>
          buildDealAction({
            deal,
            accountId: currentAccountId.value,
            t,
            isRecent: true,
            router,
            locale: resolvedLocale?.value,
          })
        )
      : [];

    return [...contactActions, ...dealActions];
  });

  return {
    crmRecentHotKeys,
    buildContactAction,
    buildDealAction,
    normalizeText,
    extractInitials,
    formatCurrency,
  };
}
