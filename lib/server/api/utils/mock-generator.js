import { SECTION_ORDER, SECTIONS } from "../constants/sections.js";

const defaultComposition = {
  [SECTIONS.LISTENING]: { total: 40, byDifficulty: { easy: 12, medium: 16, hard: 12 } },
  [SECTIONS.READING]: { total: 40, byDifficulty: { easy: 12, medium: 16, hard: 12 } },
  [SECTIONS.WRITING]: { total: 2, byDifficulty: { medium: 2 } },
  [SECTIONS.SPEAKING]: { total: 3, byDifficulty: { easy: 1, medium: 1, hard: 1 } },
};

const difficultyKeys = ["easy", "medium", "hard"];

function sampleWithoutReplacement(items, count) {
  const copy = [...items];
  const out = [];
  while (copy.length && out.length < count) {
    const idx = Math.floor(Math.random() * copy.length);
    out.push(copy[idx]);
    copy.splice(idx, 1);
  }
  return out;
}

function normalizeSectionCount(template, section, fallback) {
  const map = template?.sectionQuestionCount || {};
  const value = Number(map[section]);
  if (!Number.isFinite(value) || value <= 0) {
    return fallback;
  }
  return Math.floor(value);
}

function normalizeDifficultyRatios(template) {
  const map = template?.difficultyDistribution || {};
  const values = difficultyKeys.map((key) => Math.max(0, Number(map[key]) || 0));
  const sum = values.reduce((acc, v) => acc + v, 0);
  if (sum <= 0) {
    return { easy: 0.3, medium: 0.4, hard: 0.3 };
  }
  return {
    easy: values[0] / sum,
    medium: values[1] / sum,
    hard: values[2] / sum,
  };
}

function buildSectionComposition(section, template) {
  const fallback = defaultComposition[section] || { total: 0, byDifficulty: {} };
  const total = normalizeSectionCount(template, section, fallback.total);

  if (section === SECTIONS.WRITING) {
    return { total, byDifficulty: { medium: total } };
  }

  const ratios = normalizeDifficultyRatios(template);
  const byDifficulty = {
    easy: Math.floor(total * ratios.easy),
    medium: Math.floor(total * ratios.medium),
    hard: Math.floor(total * ratios.hard),
  };

  let assigned = byDifficulty.easy + byDifficulty.medium + byDifficulty.hard;
  while (assigned < total) {
    // Fill leftover slots in order of highest ratio first.
    const order = [...difficultyKeys].sort((a, b) => ratios[b] - ratios[a]);
    for (const key of order) {
      if (assigned >= total) break;
      byDifficulty[key] += 1;
      assigned += 1;
    }
  }

  return { total, byDifficulty };
}

function addUnique(source, output, selectedIds, count) {
  for (const item of source) {
    if (output.length >= count) break;
    const id = String(item._id);
    if (selectedIds.has(id)) continue;
    output.push(item);
    selectedIds.add(id);
  }
}

export function buildMockQuestions(questionPoolBySection, recentQuestionIds = new Set(), template = null) {
  // Builds a full mock test by selecting questions from the pool across all IELTS sections.
  // Implements difficulty-stratified random sampling with repetition prevention:
  // - Tracks recent questions across last 20 completed sessions (via recentQuestionIds).
  // - Allows up to 25% repetition per section when fresh questions are insufficient.
  // - Fallback behavior: if all fresh questions are exhausted, allows repeats up to 25%.
  // - Last resort: if bank is critically small, repeats remaining questions to fill test.
  const selected = {};
  const maxRepeatRate = 0.25;

  for (const section of SECTION_ORDER) {
    const config = buildSectionComposition(section, template);
    const sectionPool = questionPoolBySection[section] || [];
    const freshPool = sectionPool.filter((q) => !recentQuestionIds.has(String(q._id)));
    const repeatedPool = sectionPool.filter((q) => recentQuestionIds.has(String(q._id)));
    const selectedIds = new Set();
    const picks = [];
    const maxRepeated = Math.floor(config.total * maxRepeatRate);
    let repeatedUsed = 0;

    for (const [difficulty, size] of Object.entries(config.byDifficulty)) {
      const freshBucket = sampleWithoutReplacement(
        freshPool.filter((q) => q.difficulty === difficulty),
        size
      );
      addUnique(freshBucket, picks, selectedIds, config.total);

      const missing = size - freshBucket.length;
      if (missing > 0 && repeatedUsed < maxRepeated) {
        const cap = Math.min(missing, maxRepeated - repeatedUsed);
        const repeatedBucket = sampleWithoutReplacement(
          repeatedPool.filter((q) => q.difficulty === difficulty),
          cap
        );
        addUnique(repeatedBucket, picks, selectedIds, config.total);
        repeatedUsed += repeatedBucket.length;
      }
    }

    if (picks.length < config.total) {
      addUnique(sampleWithoutReplacement(freshPool, config.total), picks, selectedIds, config.total);
    }

    if (picks.length < config.total && repeatedUsed < maxRepeated) {
      const cap = Math.min(config.total - picks.length, maxRepeated - repeatedUsed);
      const before = picks.length;
      addUnique(sampleWithoutReplacement(repeatedPool, cap), picks, selectedIds, config.total);
      repeatedUsed += Math.max(0, picks.length - before);
    }

    if (picks.length < config.total) {
      // Last resort to keep generation available when question bank is small.
      addUnique(sampleWithoutReplacement(sectionPool, config.total), picks, selectedIds, config.total);
    }

    selected[section] = picks.slice(0, config.total);
  }

  return selected;
}
