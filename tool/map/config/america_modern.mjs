// North America today: the United States, Canada, Mexico, Central America
// and the Caribbean as they stand, at peace. Puerto Rico goes with the
// United States.

import { COUNTRIES_TODAY, USA_FLAG } from './america_states.mjs';

export const SCENARIO_META = {
  id: 'americaModern',
  name: 'North America today',
  startYear: 2026,
  startMonth: 1,
  // Wars are rare: the player sets the pace.
  aggression: 0.03,
};

export const DEFAULT_READY = 0.7;
export const DEFAULT_TECH = [1, 1];

const TECH = { USA: [4, 4], CAN: [3, 4], MEX: [1, 2], CUB: [1, 0], PAN: [0, 2], CRI: [0, 2], BHS: [0, 2], TTO: [0, 2] };

export const NATIONS = [
  { tag: 'USA', name: 'United States of America', short: 'United States', color: '#4A6FA5', capital: [-77.04, 38.9], flag: USA_FLAG, ready: 0.8, tech: TECH.USA },
  ...Object.entries(COUNTRIES_TODAY).map(([tag, c]) => ({ tag, ...c, tech: TECH[tag] })),
];

export const ownerOf = (p) => (p.modern === 'PRI' ? 'USA' : p.modern);

const DEVELOPMENT = { USA: 1.3, CAN: 1.25, MEX: 0.75, BHS: 0.9, TTO: 0.85, PAN: 0.8, CRI: 0.8 };
export const developmentOf = (p) => DEVELOPMENT[ownerOf(p)] ?? 0.6;

export const ALLIANCES = [['USA', 'CAN']];
export const WARS = [];
export const FORTS = {};
