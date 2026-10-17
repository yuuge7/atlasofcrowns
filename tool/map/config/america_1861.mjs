// The Civil War, April 1861: Fort Sumter has fallen and eleven states have
// left the Union. Britain holds Canada and its islands, Spain has just taken
// Santo Domingo back, Russia still owns Alaska, and the far north is nobody's.

export const SCENARIO_META = {
  id: 'america1861',
  name: 'The Civil War',
  startYear: 1861,
  startMonth: 4,
  // Fewer wars of conquest than in Europe's age of empires.
  aggression: 0.6,
};

export const DEFAULT_READY = 0.6;
export const DEFAULT_TECH = [0, 0];

export const NATIONS = [
  { tag: 'USA', name: 'United States of America', short: 'Union', color: '#4A6FA5', capital: [-77.04, 38.9], flag: 'canton:#3C3B6E,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234', ready: 0.4, tech: [1, 2] },
  { tag: 'CSA', name: 'Confederate States of America', short: 'Confederacy', color: '#8C8C84', capital: [-77.44, 37.54], flag: 'canton:#002A8F,#FFFFFF,#BF0A30,#FFFFFF,#BF0A30', ready: 0.85, tech: [1, 0] },
  // The Empire's garrisons and fleet stand behind its colonies.
  { tag: 'GBR', name: 'British North America', short: 'Britain', color: '#C9475E', capital: [-75.7, 45.42], flag: 'union', ready: 1.2, tech: [3, 3], aggression: 0.4 },
  { tag: 'MEX', name: 'Mexican Republic', short: 'Mexico', color: '#5E9B5A', capital: [-99.13, 19.43], flag: 'v:#006847,#FFFFFF,#CE1126', ready: 0.6, aggression: 0.4 },
  { tag: 'SPA', name: 'Spanish West Indies', short: 'Spain', color: '#E6C744', capital: [-82.37, 23.13], flag: 'h:#AA151B,#F1BF00,#F1BF00,#AA151B', ready: 0.5, tech: [1, 1], aggression: 0.4 },
  { tag: 'RUS', name: 'Russian America', short: 'Russia', color: '#4C7D55', capital: [-135.33, 57.05], flag: 'h:#FFFFFF,#0039A6,#D52B1E', ready: 0.3, tech: [1, 0], aggression: 0.4 },
  { tag: 'HTI', name: 'Republic of Haiti', short: 'Haiti', color: '#3F86A0', capital: [-72.33, 18.54], flag: 'h:#00209F,#D21034' },
  { tag: 'GTM', name: 'Republic of Guatemala', short: 'Guatemala', color: '#5AA9E6', capital: [-90.51, 14.64], flag: 'v:#4997D0,#FFFFFF,#4997D0' },
  { tag: 'SLV', name: 'Republic of El Salvador', short: 'El Salvador', color: '#2F6FBF', capital: [-89.19, 13.69], flag: 'h:#0F47AF,#FFFFFF,#0F47AF' },
  { tag: 'HND', name: 'Republic of Honduras', short: 'Honduras', color: '#8ED3DD', capital: [-87.2, 14.07], flag: 'h:#0073CF,#FFFFFF,#0073CF' },
  { tag: 'NIC', name: 'Republic of Nicaragua', short: 'Nicaragua', color: '#A8B04A', capital: [-86.27, 12.13], flag: 'h:#0067C6,#FFFFFF,#0067C6' },
  { tag: 'CRI', name: 'Republic of Costa Rica', short: 'Costa Rica', color: '#D98CB0', capital: [-84.08, 9.93], flag: 'h:#002B7F,#FFFFFF,#CE1126,#CE1126,#FFFFFF,#002B7F' },
  { tag: 'NGR', name: 'Granadine Confederation', short: 'New Granada', color: '#A8743B', capital: [-79.52, 8.98], flag: 'h:#FCD116,#FCD116,#003893,#CE1126' },
  { tag: 'UNC', name: 'Unclaimed land', short: 'Unclaimed', color: '#F2EDDF', capital: [-110, 63], wild: true },
];

const CONFEDERATE = ['SC', 'MS', 'FL', 'AL', 'GA', 'LA', 'TX', 'VA', 'AR', 'NC', 'TN', 'OK'];

export function ownerOf(p) {
  const lat = p.lonLat[1];
  switch (p.modern) {
    case 'USA': {
      const state = p.owner.slice(3);
      if (state === 'AK') return 'RUS';
      return CONFEDERATE.includes(state) ? 'CSA' : 'USA';
    }
    case 'CAN': {
      // The colonies and the settled south of Rupert's Land; north of it,
      // only trading posts.
      const province = p.owner.slice(3);
      if (['YT', 'NT', 'NU'].includes(province)) return 'UNC';
      return lat < (province === 'BC' ? 55.5 : 52.5) || ['NS', 'NB', 'PE', 'NL'].includes(province) ? 'GBR' : 'UNC';
    }
    case 'CUB':
    case 'PRI':
    case 'DOM':
      return 'SPA';
    case 'BLZ':
    case 'JAM':
    case 'BHS':
    case 'TTO':
      return 'GBR';
    case 'PAN':
      return 'NGR';
    default:
      return p.modern;
  }
}

const DEVELOPMENT = { USA: 0.8, CSA: 0.75, GBR: 0.9, SPA: 0.55, MEX: 0.45, RUS: 0.3, UNC: 0.15 };
export const developmentOf = (p) => DEVELOPMENT[ownerOf(p)] ?? 0.4;

export const WARS = [['CSA', 'USA']];
export const ALLIANCES = [];

/** Fortifications by province name on the map: the capitals' rings of forts, and the river and harbour strongholds. */
export const FORTS = {
  'Washington, D.C.': 2,
  'St. Louis': 1,
  Richmond: 2,
  Alexandria: 1,
  Charleston: 1,
  'New Orleans': 1,
  Jackson: 1,
  Atlanta: 1,
  Halifax: 2,
  Montréal: 1,
  Toronto: 1,
  Victoria: 1,
};
