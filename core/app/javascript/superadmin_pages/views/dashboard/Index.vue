<script setup>
import { computed } from 'vue';
import BarChart from 'shared/components/charts/BarChart.vue';

const props = defineProps({
  componentData: {
    type: Object,
    default: () => ({}),
  },
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
        label: 'Conversas',
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
    description: 'Ambientes operacionais sob governanca',
  },
  {
    label: 'Usuarios',
    value: usersCount,
    description: 'Pessoas com acesso a plataforma',
  },
  {
    label: 'Caixas',
    value: inboxesCount,
    description: 'Canais de comunicacao configurados',
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
      peakLabel: 'Sem dados',
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
      <header class="superadmin-dashboard__hero" role="banner">
        <div class="max-w-3xl">
          <span class="superadmin-dashboard__eyebrow">Controle principal</span>
          <h1 id="page-title" class="superadmin-dashboard__title">
            Painel Super Admin
          </h1>
          <p class="superadmin-dashboard__description">
            Governanca, crescimento e saude operacional em uma unica tela.
            Revise escala de contas, carga de comunicacao e postura atual do sistema.
          </p>
        </div>

        <div class="superadmin-dashboard__status">
          <span class="superadmin-dashboard__status-label">Pico de atividade</span>
          <strong class="text-[rgb(var(--slate-12))]">{{ chartSummary.peakLabel }}</strong>
          <span class="text-[rgb(var(--slate-10))]">{{ chartSummary.peakValue }} conversas</span>
        </div>
      </header>

      <section class="grid gap-6 lg:grid-cols-[1.4fr_0.9fr]">
        <div class="grid gap-6 sm:grid-cols-2">
          <article
            v-for="card in metricCards"
            :key="card.label"
            class="superadmin-dashboard__metric-card"
          >
            <span class="superadmin-dashboard__metric-label">{{ card.label }}</span>
            <strong class="superadmin-dashboard__metric-value">{{ card.value }}</strong>
            <p class="mb-0 text-sm text-[rgb(var(--slate-10))]">
              {{ card.description }}
            </p>
          </article>
        </div>

        <aside class="superadmin-dashboard__insight-card">
          <span class="superadmin-dashboard__metric-label">Resumo do trafego</span>
          <div class="mt-4 grid grid-cols-2 gap-4">
            <div>
              <div class="text-2xl font-semibold text-[rgb(var(--slate-12))]">
                {{ chartSummary.total }}
              </div>
              <div class="text-sm text-[rgb(var(--slate-10))]">Conversas no periodo do grafico</div>
            </div>
            <div>
              <div class="text-2xl font-semibold text-[rgb(var(--slate-12))]">
                {{ chartSummary.average }}
              </div>
              <div class="text-sm text-[rgb(var(--slate-10))]">Media por intervalo</div>
            </div>
          </div>
          <p class="mt-5 mb-0 text-sm leading-6 text-[rgb(var(--slate-10))]">
            Use este painel como ponto rapido de verificacao operacional para acompanhar crescimento e uso da instancia.
          </p>
        </aside>
      </section>

      <section class="superadmin-dashboard__chart-panel">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <span class="superadmin-dashboard__metric-label">Volume de conversas</span>
            <h2 class="mt-2 mb-0 text-xl font-semibold text-[rgb(var(--slate-12))]">Distribuicao de atividade</h2>
          </div>
          <p class="mb-0 max-w-xl text-sm text-[rgb(var(--slate-10))]">
            Visao geral do volume de conversas no periodo atual.
          </p>
        </div>

        <BarChart
          class="mt-6 w-full"
          :collection="chartData"
          style="max-height: 420px"
        />
      </section>
    </div>
  </div>
</template>

<style scoped>
.superadmin-dashboard__hero,
.superadmin-dashboard__metric-card,
.superadmin-dashboard__insight-card,
.superadmin-dashboard__chart-panel {
  border: 1px solid rgb(var(--slate-4) / 0.4);
  border-radius: 0.85rem;
  background: rgb(var(--slate-2));
}

.superadmin-dashboard__hero,
.superadmin-dashboard__chart-panel {
  padding: 24px;
}

.superadmin-dashboard__metric-card,
.superadmin-dashboard__insight-card {
  padding: 24px;
}

.superadmin-dashboard__eyebrow,
.superadmin-dashboard__metric-label,
.superadmin-dashboard__status-label {
  display: inline-flex;
  font-family: 'Inter', sans-serif;
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  color: rgb(var(--slate-10));
}

.superadmin-dashboard__eyebrow {
  padding: 0.3rem 0.7rem;
  border-radius: 0.7rem;
  background: rgb(var(--slate-3));
}

.superadmin-dashboard__title {
  margin: 0.75rem 0 0;
  font-family: 'Inter', sans-serif;
  font-size: clamp(1.5rem, 3.5vw, 2.25rem);
  font-weight: 700;
  line-height: 1.15;
  color: rgb(var(--slate-12));
}

.superadmin-dashboard__description {
  max-width: 44rem;
  margin-top: 0.75rem;
  font-size: 0.9rem;
  line-height: 1.6;
  color: rgb(var(--slate-10));
}

.superadmin-dashboard__status {
  display: flex;
  min-width: 14rem;
  flex-direction: column;
  gap: 0.25rem;
  padding: 1rem;
  border-radius: 0.625rem;
  background: rgb(var(--slate-3) / 0.4);
}

.superadmin-dashboard__metric-value {
  display: block;
  margin: 0.5rem 0 0.25rem;
  font-family: 'Inter', sans-serif;
  font-size: clamp(1.75rem, 3vw, 2.25rem);
  font-weight: 700;
  line-height: 1;
  color: rgb(var(--iris-9));
}

@media (min-width: 768px) {
  .superadmin-dashboard__hero {
    display: flex;
    justify-content: space-between;
    gap: 1.5rem;
    align-items: flex-end;
  }
}
</style>
