import { frontendURL } from '../../../helper/URLHelper';
import ContactsDashboardLayout from './pages/ContactsDashboardLayout.vue';
import ContactsIndex from './pages/ContactsIndex.vue';
import ContactCategoriesPage from './pages/ContactCategoriesPage.vue';
import ContactManageView from './pages/ContactManageView.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.CRM,
  permissions: ['administrator', 'agent', 'contact_manage'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/contacts'),
    component: ContactsDashboardLayout,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'contacts_dashboard_index',
        component: ContactsIndex,
        meta: commonMeta,
      },
      {
        path: 'segments/:segmentId',
        name: 'contacts_dashboard_segments_index',
        component: ContactsIndex,
        meta: commonMeta,
      },
      {
        path: 'labels/:label',
        name: 'contacts_dashboard_labels_index',
        component: ContactsIndex,
        meta: commonMeta,
      },
      {
        path: 'categories',
        name: 'contacts_dashboard_categories',
        component: ContactCategoriesPage,
        meta: commonMeta,
      },
      {
        path: 'categories/:kind',
        name: 'contacts_dashboard_category_kind',
        component: ContactCategoriesPage,
        meta: commonMeta,
      },
      {
        path: 'categories/:kind/:categoryId',
        name: 'contacts_dashboard_category_detail',
        component: ContactCategoriesPage,
        meta: commonMeta,
      },
      {
        path: 'list',
        name: 'contacts_dashboard_list',
        component: ContactsIndex,
        meta: commonMeta,
      },
      {
        path: 'active',
        name: 'contacts_dashboard_active',
        redirect: to => ({
          name: 'contacts_dashboard_index',
          params: to.params,
          query: { page: 1 },
        }),
        meta: commonMeta,
      },
    ],
  },
  {
    path: frontendURL('accounts/:accountId/contacts/:contactId'),
    component: ContactManageView,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'contacts_edit',
        component: ContactManageView,
        meta: commonMeta,
      },
      {
        path: 'segments/:segmentId',
        name: 'contacts_edit_segment',
        component: ContactManageView,
        meta: commonMeta,
      },
      {
        path: 'labels/:label',
        name: 'contacts_edit_label',
        component: ContactManageView,
        meta: commonMeta,
      },
    ],
  },
];
