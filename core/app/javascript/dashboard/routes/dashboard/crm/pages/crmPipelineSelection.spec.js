import {
  countOperationalAlertCategories,
  selectInitialCrmPipelineId,
} from './crmPipelineSelection';

describe('selectInitialCrmPipelineId', () => {
  const pipelines = [
    { id: 1, is_default: true, open_deals_count: 0 },
    { id: 2, open_deals_count: 189 },
    { id: 6, open_deals_count: 6 },
  ];

  it('keeps an explicitly requested pipeline', () => {
    expect(selectInitialCrmPipelineId(pipelines, '6')).toBe('6');
  });

  it('selects the pipeline with the most open deals when the default is empty', () => {
    expect(selectInitialCrmPipelineId(pipelines)).toBe('2');
  });

  it('keeps the default pipeline when it contains open deals', () => {
    expect(
      selectInitialCrmPipelineId([
        { id: 1, is_default: true, open_deals_count: 4 },
        { id: 2, open_deals_count: 10 },
      ])
    ).toBe('1');
  });

  it('preserves the old default behavior when counts are unavailable', () => {
    expect(
      selectInitialCrmPipelineId([{ id: 1, is_default: true }, { id: 2 }])
    ).toBe('1');
  });
});

describe('countOperationalAlertCategories', () => {
  it('counts alert categories instead of summing affected records', () => {
    expect(
      countOperationalAlertCategories([
        { tone: 'warn', value: 2683 },
        { tone: 'danger', value: 34 },
        { tone: 'ok', value: 0 },
        { tone: 'warn', value: 3064 },
      ])
    ).toBe(3);
  });
});
