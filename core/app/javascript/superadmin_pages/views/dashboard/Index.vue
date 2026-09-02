<script setup>
import { computed } from 'vue';
import BarChart from 'shared/components/charts/BarChart.vue';

const props = defineProps({
  componentData: {
    type: Object,
    default: () => ({}),
  },
});

const dashboardCopy = Object.freeze({
  eyebrow: 'Controle principal',
  title: 'Painel Super Admin',
  description:
    'Governança, crescimento e saúde operacional em uma única tela. Revise a escala de contas, a carga de comunicação e a situação atual do sistema.',
  peakActivity: 'Pico de atividade',
  conversations: 'conversas',
  trafficSummary: 'Resumo do tráfego',
  periodConversations: 'Conversas no período do gráfico',
  averageByInterval: 'Média por intervalo',
  insight:
    'Use este painel como ponto rápido de verificação operacional para acompanhar o crescimento e o uso da instância.',
  conversationVolume: 'Volume de conversas',
  activityDistribution: 'Distribuição de atividade',
  chartDescription:
    'Visão geral do volume de conversas no período selecionado.',
  noData: 'Sem dados',
});

const prepareData = sourceData => {
  const labels = [];
  const data = [];
  sourceData.forEach(item => {
    labels.push(item[0]);
    data.push(item[1]);
  });
  return {
    labels,
    datasets: [
      {
        type: 'bar',
        backgroundColor: 'rgba(189, 194, 255, 0.8)',
        hoverBackgroundColor: 'rgba(189, 194, 255, 1)',
        yAxisID: 'y',
        label: dashboardCopy.conversations,
        data: data,
        borderRadius: 6,
        borderSkipped: false,
      },
    ],
  };
};

const chartData = computed(() => {
  return prepareData(props.componentData.chartData);
});

const { accountsCount, usersCount, inboxesCount, conversationsCount } =
  props.componentData;

const metricCards = computed(() => [
  {
    label: 'Contas',
    value: accountsCount,
    description: 'Ambientes operacionais sob governança',
  },
  {
    label: 'Usuários',
    value: usersCount,
    description: 'Pessoas com acesso à plataforma',
  },
  {
    label: 'Caixas',
    value: inboxesCount,
    description: 'Canais de comunicação configurados',
  },
  {
    label: 'Conversas',
    value: conversationsCount,
    description: 'Fluxo total de mensagens processadas',
  },
]);

const chartSummary = computed(() => {
  const points = props.componentData.chartData || [];
  if (!points.length) {
    return {
      total: 0,
      peakLabel: dashboardCopy.noData,
      peakValue: 0,
      average: 0,
    };
  }

  const total = points.reduce((sum, [, value]) => sum + value, 0);
  const peakPoint = points.reduce((peak, entry) =>
    entry[1] > peak[1] ? entry : peak
  );

  return {
    total,
    peakLabel: peakPoint[0],
    peakValue: peakPoint[1],
    average: Math.round(total / points.length),
  };
});
</script>

<template>
  <div class="superadmin-dashboard min-h-full w-full">
    <div class="flex flex-col gap-6 px-6 py-6 sm:px-8 lg:px-10">
      <header
        class="flex flex-col gap-4 border-b border-[rgb(var(--slate-4)/0.5)] pb-5 md:flex-row md:items-end md:justify-between"
        role="banner"
      >
        <div class="max-w-3xl">
          <span
            class="text-xs font-semibold uppercase text-[rgb(var(--slate-10))]"
          >
            {{ dashboardCopy.eyebrow }}
          </span>
          <h1
            id="page-title"
            class="mb-0 mt-2 text-2xl font-semibold text-[rgb(var(--slate-12))]"
          >
            {{ dashboardCopy.title }}
          </h1>
          <p
            class="mb-0 mt-2 max-w-3xl text-sm leading-6 text-[rgb(var(--slate-10))]"
          >
            {{ dashboardCopy.description }}
          </p>
        </div>

        <div
          class="flex min-w-56 flex-col gap-0.5 rounded-lg bg-[rgb(var(--slate-3)/0.5)] px-3 py-2"
        >
          <span
            class="text-xs font-semibold uppercase text-[rgb(var(--slate-10))]"
          >
            {{ dashboardCopy.peakActivity }}
          </span>
          <strong class="text-[rgb(var(--slate-12))]">{{
            chartSummary.peakLabel
          }}</strong>
          <span class="text-[rgb(var(--slate-10))]">
            {{ chartSummary.peakValue }} {{ dashboardCopy.conversations }}
          </span>
        </div>
      </header>

      <section
        class="overflow-hidden rounded-lg border border-[rgb(var(--slate-4)/0.5)] bg-[rgb(var(--slate-2))]"
      >
        <div class="grid sm:grid-cols-2 lg:grid-cols-4">
          <article
            v-for="card in metricCards"
            :key="card.label"
            class="border-b border-[rgb(var(--slate-4)/0.5)] p-4 last:border-b-0 sm:[&:nth-child(odd)]:border-r lg:border-b-0 lg:border-r lg:last:border-r-0"
          >
            <span
              class="text-xs font-semibold uppercase text-[rgb(var(--slate-10))]"
            >
              {{ card.label }}
            </span>
            <strong
              class="my-1 block text-2xl font-semibold text-[rgb(var(--iris-9))]"
            >
              {{ card.value }}
            </strong>
            <p class="mb-0 text-sm text-[rgb(var(--slate-10))]">
              {{ card.description }}
            </p>
          </article>
        </div>

        <aside
          class="flex flex-col gap-4 border-t border-[rgb(var(--slate-4)/0.5)] p-4 md:flex-row md:items-center"
        >
          <span
            class="text-xs font-semibold uppercase text-[rgb(var(--slate-10))]"
          >
            {{ dashboardCopy.trafficSummary }}
          </span>
          <div class="grid grid-cols-2 gap-6">
            <div>
              <div class="text-2xl font-semibold text-[rgb(var(--slate-12))]">
                {{ chartSummary.total }}
              </div>
              <div class="text-sm text-[rgb(var(--slate-10))]">
                {{ dashboardCopy.periodConversations }}
              </div>
            </div>
            <div>
              <div class="text-2xl font-semibold text-[rgb(var(--slate-12))]">
                {{ chartSummary.average }}
              </div>
              <div class="text-sm text-[rgb(var(--slate-10))]">
                {{ dashboardCopy.averageByInterval }}
              </div>
            </div>
          </div>
          <p
            class="mb-0 text-sm leading-6 text-[rgb(var(--slate-10))] md:ml-auto md:max-w-lg"
          >
            {{ dashboardCopy.insight }}
          </p>
        </aside>
      </section>

      <section
        class="rounded-lg border border-[rgb(var(--slate-4)/0.5)] bg-[rgb(var(--slate-2))] p-4 sm:p-6"
      >
        <div
          class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between"
        >
          <div>
            <span
              class="text-xs font-semibold uppercase text-[rgb(var(--slate-10))]"
            >
              {{ dashboardCopy.conversationVolume }}
            </span>
            <h2
              class="mt-2 mb-0 text-xl font-semibold text-[rgb(var(--slate-12))]"
            >
              {{ dashboardCopy.activityDistribution }}
            </h2>
          </div>
          <p class="mb-0 max-w-xl text-sm text-[rgb(var(--slate-10))]">
            {{ dashboardCopy.chartDescription }}
          </p>
        </div>

        <BarChart class="mt-6 max-h-[420px] w-full" :collection="chartData" />
      </section>
    </div>
  </div>
</template>
