<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref } from 'vue';

import {
  DsAvatar,
  DsBadge,
  DsButton,
  DsCard,
  DsCheckbox,
  DsInput,
  DsPagination,
  DsSelect,
  DsTabs,
  DsTooltip,
} from 'dashboard/design-system/components';
import {
  BoardPageTemplate,
  CalendarPageTemplate,
  ConversationPageTemplate,
  ListPageTemplate,
  RecordPageTemplate,
  SettingsPageTemplate,
} from 'dashboard/design-system/templates';

const archetype = ref('list');
const viewState = ref('default');
const search = ref('');
const status = ref('all');
const page = ref(1);
const notifications = ref(true);

const archetypeTabs = [
  { value: 'list', label: 'Lista' },
  { value: 'board', label: 'Quadro' },
  { value: 'record', label: 'Registro' },
  { value: 'conversation', label: 'Conversa' },
  { value: 'calendar', label: 'Calendário' },
  { value: 'settings', label: 'Configuração' },
];

const stateTabs = [
  { value: 'default', label: 'Padrão' },
  { value: 'loading', label: 'Carregando' },
  { value: 'empty', label: 'Vazio' },
];

const leads = [
  {
    id: 1,
    name: 'Ana Carolina Alves',
    company: 'Alves Comércio',
    stage: 'Qualificação',
    score: 82,
    owner: 'Paula Matos',
  },
  {
    id: 2,
    name: 'George Ferreira',
    company: 'Ferreira Serviços',
    stage: 'Documentos',
    score: 68,
    owner: 'Letícia Souza',
  },
  {
    id: 3,
    name: 'Alex Rodrigues',
    company: 'Pessoa física',
    stage: 'Análise jurídica',
    score: 91,
    owner: 'Paula Matos',
  },
  {
    id: 4,
    name: 'Marina Oliveira',
    company: 'Oliveira Transportes',
    stage: 'Primeiro contato',
    score: 54,
    owner: 'Ingrid Lima',
  },
];

const boardColumns = [
  {
    id: 'new',
    label: 'Novos',
    total: 'R$ 42 mil',
    items: [
      ['Ana Carolina Alves', 'Aposentadoria', '82'],
      ['Marina Oliveira', 'Benefício assistencial', '54'],
    ],
  },
  {
    id: 'qualification',
    label: 'Qualificação',
    total: 'R$ 68 mil',
    items: [
      ['George Ferreira', 'Revisão de benefício', '68'],
      ['Carlos Mendes', 'Auxílio por incapacidade', '73'],
    ],
  },
  {
    id: 'documents',
    label: 'Documentos',
    total: 'R$ 31 mil',
    items: [['Beatriz Rocha', 'Pensão por morte', '76']],
  },
  {
    id: 'analysis',
    label: 'Análise jurídica',
    total: 'R$ 57 mil',
    items: [['Alex Rodrigues', 'Aposentadoria por invalidez', '91']],
  },
];

const conversations = [
  ['Ana Carolina', 'Enviei os documentos solicitados.', '2 min'],
  ['George Ferreira', 'Obrigado pelo retorno, Dra. Paula.', '11 min'],
  ['Alex Rodrigues', 'Posso enviar meu CNIS por aqui?', '24 min'],
  ['Marina Oliveira', 'Quero entender os próximos passos.', '1 h'],
];

const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const days = Array.from({ length: 35 }, (_, index) => index + 1);

const isLoading = computed(() => viewState.value === 'loading');
const isEmpty = computed(() => viewState.value === 'empty');
const commonBreadcrumbs = [{ label: 'CRM' }, { label: 'Modelos de página' }];
</script>

<template>
  <div class="flex h-full min-h-0 w-full min-w-0 flex-1 flex-col bg-ui-canvas">
    <div
      class="flex shrink-0 flex-col gap-3 border-b border-ui-border bg-ui-surface px-4 py-3 lg:flex-row lg:items-center lg:justify-between"
    >
      <DsTabs
        v-model="archetype"
        :tabs="archetypeTabs"
        label="Arquétipo de página"
      />
      <DsTabs
        v-model="viewState"
        :tabs="stateTabs"
        label="Estado do template"
      />
    </div>

    <ListPageTemplate
      v-if="archetype === 'list'"
      title="Leads"
      :breadcrumbs="commonBreadcrumbs"
      :loading="isLoading"
      :empty="isEmpty"
      empty-title="Nenhum lead corresponde aos filtros."
      empty-action-label="Limpar filtros"
    >
      <template #actions>
        <DsButton variant="secondary" label="Importar" />
        <DsButton variant="primary" label="Novo lead" icon="i-lucide-plus" />
      </template>
      <template #metrics>
        <DsCard
          v-for="metric in [
            ['Precisam de contato', '12', 'warning'],
            ['Documentos pendentes', '8', 'danger'],
            ['Sem responsável', '5', 'info'],
            ['Score acima de 80', '21', 'success'],
          ]"
          :key="metric[0]"
          interactive
          padding="sm"
        >
          <p class="m-0 text-ui-caption text-ui-text-muted">{{ metric[0] }}</p>
          <div class="mt-1 flex items-center justify-between">
            <strong class="text-ui-heading tabular-nums">{{ metric[1] }}</strong>
            <DsBadge :variant="metric[2]" label="Filtrar" />
          </div>
        </DsCard>
      </template>
      <template #toolbar>
        <DsInput
          v-model="search"
          label="Buscar leads"
          hide-label
          placeholder="Buscar por nome, CPF ou telefone"
          class="min-w-64 flex-1"
        >
          <template #prefix>
            <span class="i-lucide-search size-4" aria-hidden="true" />
          </template>
        </DsInput>
        <DsSelect
          v-model="status"
          label="Etapa"
          hide-label
          class="w-44"
          :options="[
            { value: 'all', label: 'Todas as etapas' },
            { value: 'qualification', label: 'Qualificação' },
            { value: 'documents', label: 'Documentos' },
          ]"
        />
        <DsButton
          variant="secondary"
          label="Filtros"
          icon="i-lucide-list-filter"
        />
      </template>
      <table class="w-full min-w-[52rem] border-collapse">
        <caption class="sr-only">
          Leads do CRM
        </caption>
        <thead class="bg-ui-sunken">
          <tr>
            <th class="w-12 px-4 py-3 text-left">
              <DsCheckbox :model-value="false" aria-label="Selecionar todos" />
            </th>
            <th
              v-for="heading in ['Lead', 'Etapa', 'Score', 'Responsável']"
              :key="heading"
              scope="col"
              class="px-3 py-3 text-left text-ui-caption font-semibold uppercase tracking-wide text-ui-text-muted"
            >
              {{ heading }}
            </th>
            <th scope="col" class="w-24 px-3 py-3">
              <span class="sr-only">Ações</span>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-ui-border-subtle">
          <tr v-for="lead in leads" :key="lead.id" class="hover:bg-ui-hover">
            <td class="px-4 py-3">
              <DsCheckbox
                :model-value="false"
                :aria-label="`Selecionar ${lead.name}`"
              />
            </td>
            <td class="px-3 py-3">
              <div class="flex items-center gap-3">
                <DsAvatar :name="lead.name" />
                <div>
                  <p class="m-0 text-ui-body font-medium">{{ lead.name }}</p>
                  <p class="m-0 text-ui-caption text-ui-text-muted">
                    {{ lead.company }}
                  </p>
                </div>
              </div>
            </td>
            <td class="px-3 py-3">
              <DsBadge :label="lead.stage" variant="neutral" />
            </td>
            <td class="px-3 py-3 font-medium tabular-nums">
              {{ lead.score }}
            </td>
            <td class="px-3 py-3 text-ui-body-sm">{{ lead.owner }}</td>
            <td class="px-3 py-3">
              <div class="flex justify-end gap-1">
                <DsTooltip text="Abrir lead">
                  <template #default="{ tooltipId }">
                    <DsButton
                      icon="i-lucide-arrow-up-right"
                      variant="ghost"
                      size="sm"
                      aria-label="Abrir lead"
                      :aria-describedby="tooltipId"
                    />
                  </template>
                </DsTooltip>
                <DsTooltip text="Mais ações">
                  <template #default="{ tooltipId }">
                    <DsButton
                      icon="i-lucide-ellipsis"
                      variant="ghost"
                      size="sm"
                      aria-label="Mais ações"
                      :aria-describedby="tooltipId"
                    />
                  </template>
                </DsTooltip>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <template #pagination>
        <DsPagination
          v-model:current-page="page"
          :total-items="84"
          :items-per-page="20"
        />
      </template>
    </ListPageTemplate>

    <BoardPageTemplate
      v-else-if="archetype === 'board'"
      title="Pipeline comercial"
      :breadcrumbs="commonBreadcrumbs"
      :loading="isLoading"
      :empty="isEmpty"
      empty-title="Nenhum negócio neste pipeline."
      empty-action-label="Criar negócio"
    >
      <template #actions>
        <DsButton variant="secondary" label="Configurar pipeline" />
        <DsButton variant="primary" label="Novo negócio" icon="i-lucide-plus" />
      </template>
      <template #toolbar>
        <DsInput
          v-model="search"
          label="Buscar no pipeline"
          hide-label
          placeholder="Buscar negócio"
          class="min-w-60 flex-1"
        />
        <DsButton variant="secondary" label="Responsável" />
        <DsButton variant="secondary" label="Período" />
      </template>
      <section
        v-for="column in boardColumns"
        :key="column.id"
        class="flex h-full w-72 shrink-0 flex-col rounded-ui-surface border border-ui-border-subtle bg-ui-sunken"
        :aria-labelledby="`column-${column.id}`"
      >
        <header class="flex items-center justify-between px-3 py-3">
          <div>
            <h2
              :id="`column-${column.id}`"
              class="m-0 text-ui-body font-semibold"
            >
              {{ column.label }}
            </h2>
            <p class="m-0 text-ui-caption text-ui-text-muted">
              {{ column.items.length }} · {{ column.total }}
            </p>
          </div>
          <DsButton
            icon="i-lucide-ellipsis"
            variant="ghost"
            size="sm"
            :aria-label="`Ações de ${column.label}`"
          />
        </header>
        <div class="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto px-2 pb-2">
          <DsCard
            v-for="item in column.items"
            :key="item[0]"
            interactive
            padding="sm"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <p class="m-0 truncate text-ui-body font-medium">
                  {{ item[0] }}
                </p>
                <p class="mt-1 line-clamp-2 text-ui-caption text-ui-text-muted">
                  {{ item[1] }}
                </p>
              </div>
              <DsBadge :label="item[2]" variant="brand" />
            </div>
            <p class="mb-0 mt-3 text-ui-caption text-ui-text-muted">
              Próxima ação hoje, 16:30
            </p>
          </DsCard>
        </div>
      </section>
    </BoardPageTemplate>

    <RecordPageTemplate
      v-else-if="archetype === 'record'"
      title="Alex Rodrigues"
      :breadcrumbs="[
        { label: 'CRM' },
        { label: 'Negócios' },
        { label: 'Alex Rodrigues' },
      ]"
      :loading="isLoading"
      :empty="isEmpty"
      empty-title="Este negócio não está mais disponível."
      empty-action-label="Voltar aos negócios"
    >
      <template #actions>
        <DsButton variant="secondary" label="Editar" icon="i-lucide-pencil" />
        <DsButton variant="primary" label="Avançar etapa" />
        <DsButton
          variant="ghost"
          icon="i-lucide-ellipsis"
          aria-label="Mais ações"
        />
      </template>
      <template #summary>
        <DsCard>
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="flex items-center gap-3">
              <DsAvatar name="Alex Rodrigues" size="lg" status="online" />
              <div>
                <p class="m-0 text-ui-heading font-semibold">Alex Rodrigues</p>
                <p class="m-0 text-ui-body-sm text-ui-text-muted">
                  Aposentadoria por invalidez
                </p>
              </div>
            </div>
            <div class="flex flex-wrap gap-2">
              <DsBadge label="Análise jurídica" variant="info" />
              <DsBadge label="Score 91" variant="success" />
              <DsBadge label="Prioridade alta" variant="warning" />
            </div>
          </div>
        </DsCard>
      </template>
      <DsCard>
        <h2 class="m-0 text-ui-heading font-semibold">Linha do tempo</h2>
        <ol class="mt-4 divide-y divide-ui-border-subtle">
          <li
            v-for="event in [
              ['Hoje, 14:12', 'Documento recebido', 'CNIS anexado pelo WhatsApp.'],
              ['Hoje, 13:48', 'Etapa atualizada', 'Movido para análise jurídica.'],
              ['Ontem, 17:20', 'Conversa concluída', 'Atendimento feito pela Dra. Paula.'],
            ]"
            :key="event[0]"
            class="grid gap-1 py-4 sm:grid-cols-[7rem_minmax(0,1fr)]"
          >
            <time class="text-ui-caption text-ui-text-muted">{{ event[0] }}</time>
            <div>
              <p class="m-0 text-ui-body font-medium">{{ event[1] }}</p>
              <p class="m-0 text-ui-body-sm text-ui-text-muted">{{ event[2] }}</p>
            </div>
          </li>
        </ol>
      </DsCard>
      <template #context>
        <div class="flex flex-col gap-4">
          <DsCard>
            <h2 class="m-0 text-ui-body font-semibold">Dados do negócio</h2>
            <dl class="mt-3 grid gap-3 text-ui-body-sm">
              <div>
                <dt class="text-ui-caption text-ui-text-muted">Responsável</dt>
                <dd class="m-0">Dra. Paula Matos</dd>
              </div>
              <div>
                <dt class="text-ui-caption text-ui-text-muted">Valor estimado</dt>
                <dd class="m-0">R$ 18.500</dd>
              </div>
              <div>
                <dt class="text-ui-caption text-ui-text-muted">Origem</dt>
                <dd class="m-0">WhatsApp</dd>
              </div>
            </dl>
          </DsCard>
          <DsCard>
            <h2 class="m-0 text-ui-body font-semibold">Próxima ação</h2>
            <p class="mb-0 mt-2 text-ui-body-sm text-ui-text-muted">
              Revisar documentos hoje às 16:30.
            </p>
          </DsCard>
        </div>
      </template>
    </RecordPageTemplate>

    <ConversationPageTemplate
      v-else-if="archetype === 'conversation'"
      title="Conversas"
      :breadcrumbs="commonBreadcrumbs"
      :loading="isLoading"
      :empty="isEmpty"
      empty-title="Selecione uma conversa para começar."
    >
      <template #actions>
        <DsButton
          variant="secondary"
          label="Filtros"
          icon="i-lucide-list-filter"
        />
        <DsButton
          variant="primary"
          label="Nova conversa"
          icon="i-lucide-plus"
        />
      </template>
      <template #list>
        <div class="sticky top-0 z-ui-sticky bg-ui-surface p-3">
          <DsInput
            v-model="search"
            label="Buscar conversas"
            hide-label
            placeholder="Buscar conversas"
          >
            <template #prefix>
              <span class="i-lucide-search size-4" aria-hidden="true" />
            </template>
          </DsInput>
        </div>
        <button
          v-for="(conversation, index) in conversations"
          :key="conversation[0]"
          type="button"
          class="flex w-full gap-3 border-b border-ui-border-subtle p-3 text-left hover:bg-ui-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
          :class="{ 'bg-ui-active': index === 0 }"
        >
          <DsAvatar :name="conversation[0]" />
          <span class="min-w-0 flex-1">
            <span class="flex justify-between gap-2">
              <strong class="truncate text-ui-body">{{ conversation[0] }}</strong>
              <span class="shrink-0 text-ui-caption text-ui-text-muted">
                {{ conversation[2] }}
              </span>
            </span>
            <span class="mt-1 block truncate text-ui-body-sm text-ui-text-muted">
              {{ conversation[1] }}
            </span>
          </span>
        </button>
      </template>
      <div class="flex h-full min-h-0 flex-col bg-ui-canvas">
        <header
          class="flex min-h-14 shrink-0 items-center justify-between border-b border-ui-border-subtle bg-ui-surface px-4"
        >
          <div class="flex items-center gap-3">
            <DsAvatar name="Ana Carolina" status="online" />
            <div>
              <h2 class="m-0 text-ui-body font-semibold">Ana Carolina</h2>
              <p class="m-0 text-ui-caption text-ui-text-muted">WhatsApp · online</p>
            </div>
          </div>
          <DsButton
            variant="secondary"
            size="sm"
            label="Resolver"
            icon="i-lucide-check"
          />
        </header>
        <div
          class="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto p-4"
          aria-label="Mensagens"
        >
          <p
            class="m-0 max-w-[75%] self-start rounded-ui-surface bg-ui-sunken px-3 py-2 text-ui-body"
          >
            Boa tarde. Enviei os documentos solicitados.
          </p>
          <p
            class="m-0 max-w-[75%] self-end rounded-ui-surface bg-ui-brand-soft px-3 py-2 text-ui-body text-ui-text"
          >
            Recebi, Ana. Vou conferir os documentos agora.
          </p>
          <p
            class="m-0 max-w-[75%] self-end rounded-ui-surface bg-ui-brand-soft px-3 py-2 text-ui-body text-ui-text"
          >
            Se faltar algo, aviso por aqui. Tudo bem?
          </p>
        </div>
        <div class="shrink-0 border-t border-ui-border-subtle bg-ui-surface p-3">
          <label for="gallery-message" class="sr-only">Mensagem</label>
          <textarea
            id="gallery-message"
            rows="3"
            placeholder="Escreva uma mensagem"
            class="reset-base w-full resize-none rounded-ui-control border border-ui-border bg-ui-surface p-3 text-ui-body text-ui-text outline-none placeholder:text-ui-text-subtle focus:ring-2 focus:ring-ui-border-focus"
          />
          <div class="mt-2 flex justify-between">
            <DsButton
              variant="ghost"
              icon="i-lucide-paperclip"
              aria-label="Anexar arquivo"
            />
            <DsButton variant="primary" label="Enviar" />
          </div>
        </div>
      </div>
      <template #context>
        <div class="flex flex-col gap-4 p-4">
          <div class="flex items-center gap-3">
            <DsAvatar name="Ana Carolina" size="lg" />
            <div>
              <h2 class="m-0 text-ui-body font-semibold">Ana Carolina</h2>
              <p class="m-0 text-ui-caption text-ui-text-muted">Lead · Score 82</p>
            </div>
          </div>
          <DsCard padding="sm">
            <h3 class="m-0 text-ui-body font-semibold">Próxima melhor ação</h3>
            <p class="mb-0 mt-2 text-ui-body-sm text-ui-text-muted">
              Validar CNIS e confirmar tempo de contribuição.
            </p>
          </DsCard>
          <DsCard padding="sm">
            <h3 class="m-0 text-ui-body font-semibold">Documentos</h3>
            <div class="mt-3 flex flex-wrap gap-2">
              <DsBadge label="CNIS recebido" variant="success" />
              <DsBadge label="RG pendente" variant="warning" />
            </div>
          </DsCard>
        </div>
      </template>
    </ConversationPageTemplate>

    <CalendarPageTemplate
      v-else-if="archetype === 'calendar'"
      title="Agenda"
      :breadcrumbs="commonBreadcrumbs"
      :loading="isLoading"
      :empty="isEmpty"
      empty-title="Nenhum compromisso em julho."
      empty-action-label="Criar atividade"
    >
      <template #actions>
        <DsButton variant="secondary" label="Hoje" />
        <DsButton
          variant="primary"
          label="Nova atividade"
          icon="i-lucide-plus"
        />
      </template>
      <template #toolbar>
        <DsButton
          variant="ghost"
          icon="i-lucide-chevron-left"
          aria-label="Mês anterior"
        />
        <strong class="text-ui-heading">Julho de 2026</strong>
        <DsButton
          variant="ghost"
          icon="i-lucide-chevron-right"
          aria-label="Próximo mês"
        />
        <span class="flex-1" />
        <DsButton variant="secondary" label="Mês" />
      </template>
      <div
        class="grid min-h-[32rem] grid-cols-7 overflow-hidden rounded-ui-surface border border-ui-border-subtle bg-ui-surface"
      >
        <div
          v-for="weekday in weekdays"
          :key="weekday"
          class="border-b border-r border-ui-border-subtle bg-ui-sunken p-2 text-center text-ui-caption font-semibold text-ui-text-muted last:border-r-0"
        >
          {{ weekday }}
        </div>
        <button
          v-for="day in days"
          :key="day"
          type="button"
          class="min-h-20 border-b border-r border-ui-border-subtle p-2 text-left text-ui-caption hover:bg-ui-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ui-border-focus"
          :class="{ 'bg-ui-brand-soft': day === 23 }"
        >
          <span class="font-medium tabular-nums">{{ ((day + 28) % 31) + 1 }}</span>
          <span
            v-if="[4, 11, 18, 23, 29].includes(day)"
            class="mt-2 block truncate rounded-ui-control bg-ui-info-soft px-1.5 py-1 text-ui-info-foreground"
          >
            Retorno
          </span>
        </button>
      </div>
      <template #mobile>
        <div class="flex flex-col gap-3">
          <h2 class="m-0 text-ui-heading font-semibold">Hoje, 23 de julho</h2>
          <DsCard v-for="hour in ['09:30', '14:00', '16:30']" :key="hour">
            <p class="m-0 text-ui-caption text-ui-text-muted">{{ hour }}</p>
            <p class="mb-0 mt-1 text-ui-body font-medium">
              Retorno com cliente
            </p>
          </DsCard>
        </div>
      </template>
      <template #agenda>
        <DsCard>
          <h2 class="m-0 text-ui-body font-semibold">Hoje, 23 de julho</h2>
          <ol class="mt-3 divide-y divide-ui-border-subtle">
            <li
              v-for="hour in ['09:30', '14:00', '16:30']"
              :key="hour"
              class="py-3"
            >
              <p class="m-0 text-ui-caption text-ui-text-muted">{{ hour }}</p>
              <p class="m-0 text-ui-body-sm font-medium">Retorno com cliente</p>
            </li>
          </ol>
        </DsCard>
      </template>
    </CalendarPageTemplate>

    <SettingsPageTemplate
      v-else
      title="Configurações do CRM"
      :breadcrumbs="commonBreadcrumbs"
      :loading="isLoading"
      :empty="isEmpty"
      empty-title="Nenhuma configuração disponível para seu perfil."
    >
      <template #navigation>
        <div class="flex gap-1 lg:flex-col">
          <button
            v-for="(section, index) in [
              'Geral',
              'Pipelines',
              'Motivos de perda',
              'Pontuação',
              'Automações',
              'Cadências',
            ]"
            :key="section"
            type="button"
            class="shrink-0 rounded-ui-control px-3 py-2 text-left text-ui-body-sm font-medium hover:bg-ui-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ui-border-focus"
            :class="
              index === 0
                ? 'bg-ui-active text-ui-text'
                : 'text-ui-text-muted'
            "
          >
            {{ section }}
          </button>
        </div>
      </template>
      <form class="flex flex-col gap-6" @submit.prevent>
        <section>
          <h2 class="m-0 text-ui-heading font-semibold">Dados gerais</h2>
          <p class="mb-4 mt-1 text-ui-body-sm text-ui-text-muted">
            Defina os padrões usados nos novos negócios.
          </p>
          <div class="grid gap-4 sm:grid-cols-2">
            <DsInput
              model-value="Pipeline Previdenciário"
              label="Pipeline padrão"
            />
            <DsSelect
              model-value="paula"
              label="Responsável padrão"
              :options="[
                { value: 'paula', label: 'Dra. Paula Matos' },
                { value: 'leticia', label: 'Letícia Souza' },
              ]"
            />
          </div>
        </section>
        <section class="border-t border-ui-border-subtle pt-6">
          <h2 class="m-0 text-ui-heading font-semibold">Notificações</h2>
          <div class="mt-4">
            <DsCheckbox
              v-model="notifications"
              label="Alertar sobre atividades vencidas"
              description="Envia um aviso para o responsável pelo negócio."
            />
          </div>
        </section>
        <section class="border-t border-ui-border-subtle pt-6">
          <h2 class="m-0 text-ui-heading font-semibold">Classificação</h2>
          <p class="mb-4 mt-1 text-ui-body-sm text-ui-text-muted">
            O CAPITÃO usa estes critérios para sugerir a qualificação.
          </p>
          <DsCard padding="sm">
            <div class="flex items-center justify-between gap-3">
              <div>
                <p class="m-0 text-ui-body font-medium">
                  Dados mínimos para qualificar
                </p>
                <p class="m-0 text-ui-caption text-ui-text-muted">
                  Nome, telefone, área jurídica e intenção.
                </p>
              </div>
              <DsBadge label="Ativo" variant="success" />
            </div>
          </DsCard>
        </section>
      </form>
      <template #footer>
        <DsButton variant="secondary" label="Cancelar" />
        <DsButton variant="primary" label="Salvar alterações" />
      </template>
    </SettingsPageTemplate>
  </div>
</template>
