/**
 * Normalizes a string by stripping diacritics / accents, converting to lowercase and trimming.
 * @param {string} str
 * @returns {string}
 */
export const normalizeText = (str = '') => {
  if (typeof str !== 'string') return '';
  return str
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
};

/**
 * Calculates a match score for a target text against a query token.
 * Returns -1 when there is no match.
 *
 * Higher scores mean more relevant matches:
 * - Exact match: 1000
 * - Prefix match: 800 - length difference penalty
 * - Word boundary match: 650 - position penalty
 * - Substring match: 500 - position penalty
 * - Subsequence match: 200 - span penalty + consecutive bonuses
 *
 * @param {string} target - Normalized target text
 * @param {string} query - Normalized query token
 * @returns {number} Score >= 0 if match, -1 if no match
 */
export const scoreSubsequence = (target, query) => {
  if (!query) return 0;
  if (!target) return -1;
  if (target === query) return 1000;

  if (target.startsWith(query)) {
    return 800 + Math.max(0, 100 - (target.length - query.length));
  }

  const boundaryRegex = new RegExp(`(?:^|[\\s_\\-./])${query}`);
  if (boundaryRegex.test(target)) {
    const idx = target.indexOf(query);
    return 650 + Math.max(0, 50 - idx * 2);
  }

  const subIndex = target.indexOf(query);
  if (subIndex !== -1) {
    return 500 + Math.max(0, 100 - subIndex * 5);
  }

  let tIdx = 0;
  let qIdx = 0;
  let score = 200;
  let consecutiveMatches = 0;
  let firstMatchIdx = -1;

  while (tIdx < target.length && qIdx < query.length) {
    if (target[tIdx] === query[qIdx]) {
      if (firstMatchIdx === -1) firstMatchIdx = tIdx;
      qIdx += 1;
      consecutiveMatches += 1;
      score += consecutiveMatches * 15;
    } else {
      consecutiveMatches = 0;
    }
    tIdx += 1;
  }

  if (qIdx === query.length) {
    const span = tIdx - firstMatchIdx;
    const extraDistance = span - query.length;
    score -= extraDistance * 5;
    return Math.max(1, score);
  }

  return -1;
};

/**
 * Computes the overall match score of a canned response against a search query.
 * Supports multi-term queries in any word order.
 * Weighs short_code (short cut) significantly higher than content.
 *
 * @param {Object} item - Canned response item
 * @param {string} rawQuery - Search query
 * @returns {number} Score >= 0 if match, -1 if no match
 */
export const scoreCannedResponse = (item, rawQuery) => {
  const query = normalizeText(rawQuery);
  if (!query) return 0;
  if (!item) return -1;

  const shortCode = normalizeText(
    item.short_code || item.label || item.key || ''
  );
  const content = normalizeText(item.content || item.description || '');

  if (shortCode === query) return 10000;
  if (content === query) return 4000;

  const queryWords = query.split(/\s+/).filter(Boolean);

  if (queryWords.length <= 1) {
    const codeScore = scoreSubsequence(shortCode, query);
    const contentScore = scoreSubsequence(content, query);

    if (codeScore === -1 && contentScore === -1) {
      return -1;
    }

    const finalCodeScore = codeScore !== -1 ? codeScore * 10 : 0;
    const finalContentScore = contentScore !== -1 ? contentScore : 0;
    return finalCodeScore + finalContentScore;
  }

  let totalScore = 0;
  for (let i = 0; i < queryWords.length; i += 1) {
    const word = queryWords[i];
    const codeScore = scoreSubsequence(shortCode, word);
    const contentScore = scoreSubsequence(content, word);

    if (codeScore === -1 && contentScore === -1) {
      return -1;
    }

    const wordCodeScore = codeScore !== -1 ? codeScore * 10 : 0;
    const wordContentScore = contentScore !== -1 ? contentScore : 0;
    totalScore += wordCodeScore + wordContentScore;
  }

  return totalScore;
};

/**
 * Filters and sorts canned responses using fuzzy matching.
 * Tolerant to case, accents, subsequences, and multi-word ordering.
 *
 * @template T
 * @param {Array<T>} items - List of canned response objects
 * @param {string} searchKey - Search query
 * @returns {Array<T>} Filtered and sorted canned responses
 */
export const filterCannedResponses = (items = [], searchKey = '') => {
  if (!Array.isArray(items)) return [];
  if (!searchKey || !searchKey.trim()) return items;

  const scored = [];

  for (let i = 0; i < items.length; i += 1) {
    const item = items[i];
    if (item) {
      const score = scoreCannedResponse(item, searchKey);
      if (score >= 0) {
        scored.push({ item, score, originalIndex: i });
      }
    }
  }

  scored.sort((a, b) => {
    if (b.score !== a.score) {
      return b.score - a.score;
    }
    return a.originalIndex - b.originalIndex;
  });

  return scored.map(entry => entry.item);
};
