import { describe, expect, it } from 'vitest';

import {
  calculateDealRotting,
  DEFAULT_ROTTING_THRESHOLD_DAYS,
  getDaysInactive,
  getDealLastActivityDate,
  getStageRottingThreshold,
} from '../dealRotting';

describe('dealRotting helper', () => {
  const referenceNow = new Date('2026-08-30T12:00:00Z');

  describe('getDealLastActivityDate', () => {
    it('returns null for empty or invalid deals', () => {
      expect(getDealLastActivityDate(null)).toBeNull();
      expect(getDealLastActivityDate({})).toBeNull();
      expect(
        getDealLastActivityDate({ created_at: 'invalid-date' })
      ).toBeNull();
    });

    it('prefers last_activity_at over other timestamps', () => {
      const deal = {
        last_activity_at: '2026-08-28T10:00:00Z',
        stage_entered_at: '2026-08-25T10:00:00Z',
        updated_at: '2026-08-26T10:00:00Z',
        created_at: '2026-08-20T10:00:00Z',
      };
      expect(getDealLastActivityDate(deal)).toEqual(
        new Date('2026-08-28T10:00:00Z')
      );
    });

    it('falls back to stage_entered_at when last_activity_at is missing', () => {
      const deal = {
        stage_entered_at: '2026-08-25T10:00:00Z',
        updated_at: '2026-08-26T10:00:00Z',
        created_at: '2026-08-20T10:00:00Z',
      };
      expect(getDealLastActivityDate(deal)).toEqual(
        new Date('2026-08-25T10:00:00Z')
      );
    });

    it('falls back to updated_at when stage_entered_at is missing', () => {
      const deal = {
        updated_at: '2026-08-26T10:00:00Z',
        created_at: '2026-08-20T10:00:00Z',
      };
      expect(getDealLastActivityDate(deal)).toEqual(
        new Date('2026-08-26T10:00:00Z')
      );
    });

    it('falls back to created_at when nothing else is present', () => {
      const deal = {
        created_at: '2026-08-20T10:00:00Z',
      };
      expect(getDealLastActivityDate(deal)).toEqual(
        new Date('2026-08-20T10:00:00Z')
      );
    });
  });

  describe('getDaysInactive', () => {
    it('calculates full elapsed days correctly', () => {
      const deal = {
        last_activity_at: '2026-08-26T12:00:00Z', // 4 days before referenceNow
      };
      expect(getDaysInactive(deal, referenceNow)).toBe(4);
    });

    it('returns 0 if last activity is in the future or equal', () => {
      const deal = {
        last_activity_at: '2026-08-31T12:00:00Z',
      };
      expect(getDaysInactive(deal, referenceNow)).toBe(0);
    });

    it('returns 0 for deal with no dates', () => {
      expect(getDaysInactive({}, referenceNow)).toBe(0);
    });
  });

  describe('getStageRottingThreshold', () => {
    it('returns DEFAULT_ROTTING_THRESHOLD_DAYS (7) when no stage is provided', () => {
      expect(getStageRottingThreshold()).toBe(DEFAULT_ROTTING_THRESHOLD_DAYS);
      expect(getStageRottingThreshold(null)).toBe(
        DEFAULT_ROTTING_THRESHOLD_DAYS
      );
    });

    it('prefers rotting_days_threshold when specified on stage', () => {
      const stage = {
        rotting_days_threshold: 10,
        expected_duration_hours: 48,
      };
      expect(getStageRottingThreshold(stage)).toBe(10);
    });

    it('converts expected_duration_hours to days', () => {
      const stage = {
        expected_duration_hours: 72, // 3 days
      };
      expect(getStageRottingThreshold(stage)).toBe(3);
    });

    it('ensures minimum 1 day for small non-zero expected_duration_hours', () => {
      const stage = {
        expected_duration_hours: 12,
      };
      expect(getStageRottingThreshold(stage)).toBe(1);
    });
  });

  describe('calculateDealRotting', () => {
    it('returns none level and non-rotting for closed deals (won, lost, archived)', () => {
      const wonDeal = {
        status: 'won',
        created_at: '2026-08-01T12:00:00Z',
      };
      const resultWon = calculateDealRotting(wonDeal, null, referenceNow);
      expect(resultWon.isRotting).toBe(false);
      expect(resultWon.level).toBe('none');

      const lostDeal = {
        status: 'lost',
        created_at: '2026-08-01T12:00:00Z',
      };
      const resultLost = calculateDealRotting(lostDeal, null, referenceNow);
      expect(resultLost.isRotting).toBe(false);
      expect(resultLost.level).toBe('none');
    });

    it('marks open deal as late/rotting when inactive days exceed threshold', () => {
      const deal = {
        status: 'open',
        last_activity_at: '2026-08-20T12:00:00Z', // 10 days inactive
      };
      const stage = { expected_duration_hours: 120 }; // 5 days threshold

      const result = calculateDealRotting(deal, stage, referenceNow);
      expect(result.daysInactive).toBe(10);
      expect(result.threshold).toBe(5);
      expect(result.isRotting).toBe(true);
      expect(result.level).toBe('late');
      expect(result.badgeVariant).toBe('warning');
    });

    it('marks open deal as warning when inactive days are between 70% and 100% of threshold', () => {
      const deal = {
        status: 'open',
        last_activity_at: '2026-08-22T12:00:00Z', // 8 days inactive
      };
      const stage = { rotting_days_threshold: 10 }; // 8 days is 80% (>= 70%)

      const result = calculateDealRotting(deal, stage, referenceNow);
      expect(result.daysInactive).toBe(8);
      expect(result.threshold).toBe(10);
      expect(result.isRotting).toBe(false);
      expect(result.level).toBe('warning');
      expect(result.badgeVariant).toBe('warning');
    });

    it('marks open deal as ok when well below threshold', () => {
      const deal = {
        status: 'open',
        last_activity_at: '2026-08-28T12:00:00Z', // 2 days inactive
      };
      const stage = { rotting_days_threshold: 10 };

      const result = calculateDealRotting(deal, stage, referenceNow);
      expect(result.daysInactive).toBe(2);
      expect(result.threshold).toBe(10);
      expect(result.isRotting).toBe(false);
      expect(result.level).toBe('ok');
      expect(result.badgeVariant).toBe('neutral');
    });

    it('respects a custom threshold when passed directly', () => {
      const deal = {
        status: 'open',
        last_activity_at: '2026-08-27T12:00:00Z', // 3 days inactive
      };
      const stage = { rotting_days_threshold: 14 };

      // Override with custom threshold of 2 days
      const result = calculateDealRotting(deal, stage, referenceNow, 2);
      expect(result.threshold).toBe(2);
      expect(result.isRotting).toBe(true);
      expect(result.level).toBe('late');
    });
  });
});
