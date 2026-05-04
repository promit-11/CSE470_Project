const rawToBandMap = {
  listening: [
    [39, 9],
    [37, 8.5],
    [35, 8],
    [32, 7.5],
    [30, 7],
    [26, 6.5],
    [23, 6],
    [18, 5.5],
    [16, 5],
    [13, 4.5],
    [0, 4],
  ],
  reading: [
    [39, 9],
    [37, 8.5],
    [35, 8],
    [33, 7.5],
    [30, 7],
    [27, 6.5],
    [23, 6],
    [19, 5.5],
    [15, 5],
    [13, 4.5],
    [0, 4],
  ],
};

export function rawToBand(section, raw) {
  const table = rawToBandMap[section];
  if (!table) {
    return 0;
  }
  const match = table.find(([minRaw]) => raw >= minRaw);
  return match ? match[1] : 0;
}

export function roundBandHalf(score) {
  return Math.round(score * 2) / 2;
}

export function calculateOverallBand(sectionBands) {
  const values = Object.values(sectionBands).filter((v) => typeof v === "number");
  if (!values.length) {
    return 0;
  }
  const avg = values.reduce((sum, v) => sum + v, 0) / values.length;
  return roundBandHalf(avg);
}
