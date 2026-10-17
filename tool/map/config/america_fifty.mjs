// Fifty states: the Union is gone and every state stands alone, and so does
// every province and territory of Canada, with Mexico and the rest of the
// continent looking on. Nobody is at war yet.

import { CANADA, COUNTRIES_TODAY, STATES } from './america_states.mjs';

export const SCENARIO_META = {
  id: 'americaFifty',
  name: 'Fifty states',
  startYear: 2026,
  startMonth: 1,
  // Slower to war than 1914, but every state is a rival.
  aggression: 0.5,
};

export const DEFAULT_READY = 0.8;
export const DEFAULT_TECH = [2, 2];

/** States take turns at these colours, so that no two neighbours share one. */
export const PALETTE = ['#C9475E', '#4A6FA5', '#86C17A', '#E6C744', '#7C63B8', '#E08A4A', '#3F9C95', '#B5835A', '#D98CB0', '#8ED3DD', '#A8B04A', '#6F6C68'];

export const NATIONS = [
  ...STATES.map((s) => ({ tag: s.code, name: `State of ${s.name}`, short: s.name, color: 'auto', capital: s.capital, flag: s.flag })),
  ...CANADA.map((c) => ({ tag: c.code, name: c.name, short: c.short, color: 'auto', capital: c.capital, flag: c.flag, tech: [3, 4], aggression: 0.6 })),
  { tag: 'PRI', name: 'Puerto Rico', short: 'Puerto Rico', color: '#D98C7A', capital: [-66.1, 18.45], flag: 'triangle:#ED0000,#FFFFFF,#ED0000,#FFFFFF,#ED0000,#0050F0', tech: [1, 2], aggression: 0.3 },
  ...Object.entries(COUNTRIES_TODAY)
    .filter(([tag]) => tag !== 'CAN')
    // The neighbours watch more than they fight.
    .map(([tag, c]) => ({ tag, ...c, ...(tag === 'MEX' ? { tech: [0, 1], ready: 0.35 } : { tech: [0, 1] }), aggression: 0.3 })),
];

export const ownerOf = (p) => (p.modern === 'USA' || p.modern === 'CAN' ? p.owner.slice(3) : p.modern);

const DEVELOPMENT = { USA: 1.3, CAN: 1.25, MEX: 0.5, PRI: 0.9, BHS: 0.9, TTO: 0.85, PAN: 0.8, CRI: 0.8 };
export const developmentOf = (p) => DEVELOPMENT[p.modern] ?? 0.6;

export const ALLIANCES = [];
export const WARS = [];
export const FORTS = {};
