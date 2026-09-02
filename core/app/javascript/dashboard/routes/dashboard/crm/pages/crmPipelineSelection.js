const normalizePipelineId = value => {
  if (Array.isArray(value)) return normalizePipelineId(value[0]);
  return value === undefined || value === null || value === ''
    ? ''
    : String(value);
};

const openDealsCount = pipeline => {
  const rawValue = pipeline?.open_deals_count ?? pipeline?.openDealsCount;
  if (rawValue === undefined || rawValue === null || rawValue === '')
    return null;

  const value = Number(rawValue);
  return Number.isFinite(value) && value >= 0 ? value : null;
};

export const selectInitialCrmPipelineId = (
  pipelines,
  requestedPipelineId = ''
) => {
  const requestedId = normalizePipelineId(requestedPipelineId);
  if (requestedId) return requestedId;
  if (!Array.isArray(pipelines) || !pipelines.length) return '';

  const defaultPipeline = pipelines.find(
    pipeline => pipeline.is_default || pipeline.isDefault
  );
  const pipelinesWithDeals = pipelines
    .map((pipeline, index) => ({
      pipeline,
      index,
      count: openDealsCount(pipeline),
    }))
    .filter(item => item.count > 0)
    .sort(
      (first, second) =>
        second.count - first.count || first.index - second.index
    );

  if (
    defaultPipeline &&
    (openDealsCount(defaultPipeline) === null ||
      openDealsCount(defaultPipeline) > 0)
  ) {
    return normalizePipelineId(defaultPipeline.id);
  }

  return normalizePipelineId(
    pipelinesWithDeals[0]?.pipeline?.id ||
      defaultPipeline?.id ||
      pipelines[0].id
  );
};

export const countOperationalAlertCategories = cards =>
  (cards || []).filter(card => ['warn', 'danger'].includes(card?.tone)).length;
