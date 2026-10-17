// The American Revolution, July 1776: thirteen colonies have declared their
// independence and are at war with Britain, which still holds Quebec, Nova
// Scotia and the Floridas. Spain rules Louisiana, New Spain and the
// Caribbean; France keeps Saint-Domingue. West of the mountains the land
// belongs to its own nations, and much of the far west and north to nobody
// the empires would recognise. The game calls that land unclaimed: it holds
// no army, and anyone may march in and take it against its people.
//
// Native nations are drawn with the borders a game this coarse allows: whole
// provinces, roughly where each nation held sway in 1776.

export const SCENARIO_META = {
  id: 'america1776',
  name: 'The American Revolution',
  startYear: 1776,
  startMonth: 7,
  aggression: 0.7,
};

export const DEFAULT_READY = 0.9;
export const DEFAULT_TECH = [0, 0];

export const NATIONS = [
  { tag: 'USA', name: 'United States of America', short: 'United States', color: '#4A6FA5', capital: [-75.16, 39.95], flag: 'canton:#3C3B6E,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234,#FFFFFF,#B22234', ready: 0.6, tech: [0, 1] },
  { tag: 'GBR', name: 'Kingdom of Great Britain', short: 'Britain', color: '#C9475E', capital: [-71.21, 46.81], flag: 'union', ready: 0.8, tech: [2, 2] },
  { tag: 'SPA', name: 'Spanish Empire', short: 'Spain', color: '#E6C744', capital: [-99.13, 19.43], flag: 'saltire:#FFFFFF,#C8102E', ready: 0.3, tech: [1, 1], aggression: 0.05 },
  { tag: 'FRA', name: 'Kingdom of France', short: 'France', color: '#2F4F8F', capital: [-72.2, 19.76], flag: 'sun:#FFFFFF,#D4AF37', ready: 0.4, tech: [2, 2], aggression: 0.3 },
  { tag: 'IRQ', name: 'Haudenosaunee Confederacy', short: 'Haudenosaunee', color: '#7C63B8', capital: [-76.15, 43.05] },
  { tag: 'CHE', name: 'Cherokee Nation', short: 'Cherokee', color: '#B5835A', capital: [-84.2, 35.5] },
  { tag: 'MUS', name: 'Muscogee Confederacy', short: 'Muscogee', color: '#D98C7A', capital: [-85.9, 32.6] },
  { tag: 'CHO', name: 'Choctaw Nation', short: 'Choctaw', color: '#86C17A', capital: [-89.3, 32.8] },
  { tag: 'SHA', name: 'Shawnee Nation', short: 'Shawnee', color: '#A8B04A', capital: [-82.98, 39.33] },
  { tag: 'OSA', name: 'Osage Nation', short: 'Osage', color: '#E08A4A', capital: [-94.3, 37.9] },
  { tag: 'COM', name: 'Comanche Nation', short: 'Comanche', color: '#B2553F', capital: [-101, 34], aggression: 1.3 },
  { tag: 'APA', name: 'Apache Nations', short: 'Apache', color: '#D98CB0', capital: [-109, 33.5] },
  { tag: 'LAK', name: 'Lakota Nation', short: 'Lakota', color: '#3F9C95', capital: [-101.5, 44.4], aggression: 1.3 },
  { tag: 'OJI', name: 'Anishinaabe Nations', short: 'Ojibwe', color: '#5E9B5A', capital: [-92, 46.8] },
  { tag: 'CRE', name: 'Cree Nation', short: 'Cree', color: '#8ED3DD', capital: [-101, 53.8] },
  { tag: 'BLA', name: 'Blackfoot Confederacy', short: 'Blackfoot', color: '#6F6C68', capital: [-113.5, 50.5] },
  { tag: 'UNC', name: 'Unclaimed land', short: 'Unclaimed', color: '#F2EDDF', capital: [-116, 40], wild: true },
];

/** The Spanish missions and presidios of Alta California, by province on the map. */
const SPANISH_CALIFORNIA = ['San Diego', 'Los Angeles', 'San Francisco', 'San Jose', 'Oxnard', 'Santa Barbara', 'Salinas'];

/** Who held each province in July 1776, by its state, province or country. */
export function ownerOf(p) {
  const [lon, lat] = p.lonLat;
  const where = p.modern === 'USA' ? p.owner.slice(3) : p.modern === 'CAN' ? p.owner : p.modern;
  switch (where) {
    // The thirteen colonies, Vermont, and Virginia's lands beyond the mountains.
    case 'NH': case 'MA': case 'ME': case 'RI': case 'CT': case 'NJ': case 'PA': case 'DE': case 'MD': case 'VT': case 'VA': case 'WV': case 'KY':
      return 'USA';
    case 'NY':
      return lon < -75.3 ? 'IRQ' : 'USA';
    case 'NC':
      return lon < -81.6 ? 'CHE' : 'USA';
    case 'SC':
      return lon < -82.6 ? 'CHE' : 'USA';
    case 'GA':
      return lon < -83.3 ? 'MUS' : 'USA';
    case 'TN':
      return lon > -86.8 ? 'CHE' : 'CHO';
    // The Floridas: British since 1763.
    case 'FL':
      return 'GBR';
    case 'AL':
      return lat < 31.2 ? 'GBR' : lon < -87.9 ? 'CHO' : 'MUS';
    case 'MS':
      return lat < 31.2 ? 'GBR' : 'CHO';
    // Spanish Louisiana, Texas, New Mexico and the missions.
    case 'LA':
    case 'AR':
      return 'SPA';
    case 'MO':
      return lon > -92.5 ? 'SPA' : 'OSA';
    case 'KS':
    case 'OK':
      return lon > -97.5 ? 'OSA' : 'COM';
    case 'TX':
      if ((lat < 30.6 && lon > -100.5) || (lon > -95.6 && lat < 32.2)) return 'SPA';
      return lon < -103.5 ? 'APA' : 'COM';
    case 'NM':
      if (lon > -104.7) return 'COM';
      return lat > 34.3 && lon > -107.4 ? 'SPA' : 'APA';
    case 'AZ':
      return lat < 32.4 ? 'SPA' : 'APA';
    case 'CA':
      return SPANISH_CALIFORNIA.includes(p.name) ? 'SPA' : 'UNC';
    case 'CO':
      return lon > -104.6 ? 'COM' : 'UNC';
    // The plains and the lakes.
    case 'NE':
    case 'SD':
    case 'ND':
      return 'LAK';
    case 'WY':
      return lon > -106.5 ? 'LAK' : 'UNC';
    case 'MT':
      return lon < -110 && lat > 46.4 ? 'BLA' : 'UNC';
    case 'MN':
      return lat > 46 ? 'OJI' : 'LAK';
    case 'WI':
      return lat > 45 ? 'OJI' : 'UNC';
    case 'MI':
      return lon > -84.2 && lat < 43.2 ? 'GBR' : 'OJI';
    case 'OH':
    case 'IN':
      return 'SHA';
    case 'IL':
      return lon < -89.4 && lat < 39 ? 'GBR' : 'UNC';
    case 'IA':
    case 'WA':
    case 'OR':
    case 'ID':
    case 'NV':
    case 'UT':
    case 'AK':
      return 'UNC';
    // British North America and the land of the fur trade.
    case 'CA-QC':
      return lat < 49 ? 'GBR' : 'UNC';
    case 'CA-ON':
      if (lat < 46 && lon > -80) return 'GBR';
      return lat < 50 ? 'OJI' : 'CRE';
    case 'CA-NS':
    case 'CA-NB':
    case 'CA-PE':
      return 'GBR';
    case 'CA-NL':
      return lat < 51.7 ? 'GBR' : 'UNC';
    case 'CA-MB':
    case 'CA-SK':
      return lat < 56 ? 'CRE' : 'UNC';
    case 'CA-AB':
      if (lat < 53.5) return 'BLA';
      return lat < 56 ? 'CRE' : 'UNC';
    case 'CA-BC':
    case 'CA-YT':
    case 'CA-NT':
    case 'CA-NU':
      return 'UNC';
    case 'HTI':
      return 'FRA';
    case 'JAM':
    case 'BHS':
      return 'GBR';
    // New Spain, Central America and the Spanish islands.
    default:
      return 'SPA';
  }
}

const DEVELOPMENT = { USA: 0.55, GBR: 0.45, SPA: 0.3, FRA: 0.6, UNC: 0.12 };
export const developmentOf = (p) => DEVELOPMENT[ownerOf(p)] ?? 0.25;

export const WARS = [
  ['USA', 'GBR'],
  ['CHE', 'USA'],
];
export const ALLIANCES = [];

export const HISTORY = [
  {
    date: [1777, 3],
    text: 'Shawnee war parties, armed at Detroit, strike the settlements of Kentucky.',
    wars: [['SHA', 'USA']],
  },
  {
    date: [1777, 8],
    text: 'Most of the Six Nations of the Haudenosaunee side with the Crown and march with Burgoyne.',
    alliances: [['IRQ', 'GBR']],
    wars: [['IRQ', 'USA']],
  },
  {
    date: [1778, 2],
    text: 'After Saratoga, France signs a treaty of alliance with the United States and goes to war with Britain.',
    alliances: [['FRA', 'USA']],
    wars: [['FRA', 'GBR']],
  },
  {
    date: [1779, 6],
    text: 'Spain, allied to France, declares war on Britain to win back Gibraltar and the Floridas.',
    alliances: [['SPA', 'FRA']],
    wars: [['SPA', 'GBR']],
  },
];

export const FORTS = {};
