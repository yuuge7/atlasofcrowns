// North America: the map. US counties (Natural Earth admin-2) and the admin-1
// units of Canada, Mexico, Central America and the Caribbean, merged into
// provinces that never cross a US state, a Canadian province or a country.
// The scenarios played on it only assign these provinces (america_*.mjs).

export const MAP_NAME = 'america';

/** Map window in lon/lat. Mercator, so this is a rectangle on screen too. */
export const BBOX = { w: -170, s: 7, e: -52, n: 66 };

/** Countries on the map besides the United States, from admin-1. */
export const COUNTRIES = ['CAN', 'MEX', 'GTM', 'BLZ', 'SLV', 'HND', 'NIC', 'CRI', 'PAN', 'CUB', 'HTI', 'DOM', 'JAM', 'PRI', 'BHS', 'TTO'];

/** Canada's provinces are huge: they are cut along this grid before merging. */
export const GRID = { dLon: 4, dLat: 2.5, country: 'CAN' };

/** Lakes over this many km2 are cut out of the land (reservoirs stay land). */
export const LAKE_KM2 = 1500;

/** US counties outside the map's states: Hawaii, and the territories (Puerto Rico comes from admin-1). */
const NOT_STATES = ['HI', 'PR', 'VI', 'GU', 'AS', 'MP', 'UM'];

/** Every admin unit belongs to its state, province or country. */
export function classify(p) {
  if (p.adm0_a3 === 'USA') {
    if (!p.region || NOT_STATES.includes(p.region)) return null;
    return { owner: `US-${p.region === 'DC' ? 'MD' : p.region}`, group: 'USA' };
  }
  if (p.adm0_a3 === 'CAN') return { owner: p.iso_3166_2, group: 'CAN' };
  return { owner: p.adm0_a3, group: p.adm0_a3 };
}

/** Provinces per state, Canadian province and country. */
export const KEY_TARGETS = {
  'US-AL': 3, 'US-AK': 5, 'US-AZ': 4, 'US-AR': 3, 'US-CA': 8, 'US-CO': 4, 'US-CT': 1, 'US-DE': 1, 'US-FL': 5, 'US-GA': 4,
  'US-ID': 3, 'US-IL': 4, 'US-IN': 3, 'US-IA': 3, 'US-KS': 4, 'US-KY': 3, 'US-LA': 3, 'US-ME': 2, 'US-MD': 2, 'US-MA': 2,
  'US-MI': 5, 'US-MN': 4, 'US-MS': 3, 'US-MO': 4, 'US-MT': 5, 'US-NE': 4, 'US-NV': 3, 'US-NH': 1, 'US-NJ': 2, 'US-NM': 4,
  'US-NY': 5, 'US-NC': 4, 'US-ND': 3, 'US-OH': 4, 'US-OK': 4, 'US-OR': 4, 'US-PA': 4, 'US-RI': 1, 'US-SC': 3, 'US-SD': 3,
  'US-TN': 3, 'US-TX': 9, 'US-UT': 3, 'US-VT': 1, 'US-VA': 4, 'US-WA': 4, 'US-WV': 2, 'US-WI': 4, 'US-WY': 3,
  'CA-BC': 5, 'CA-AB': 3, 'CA-SK': 3, 'CA-MB': 3, 'CA-ON': 6, 'CA-QC': 6, 'CA-NB': 1, 'CA-NS': 1, 'CA-PE': 1, 'CA-NL': 2,
  'CA-YT': 1, 'CA-NT': 2, 'CA-NU': 1,
  MEX: 20, GTM: 3, BLZ: 1, SLV: 1, HND: 2, NIC: 2, CRI: 1, PAN: 2, CUB: 4, HTI: 1, DOM: 2, JAM: 1, PRI: 1, BHS: 1, TTO: 1,
};

/** Merge thresholds, km2 of real (spherical) area, as for Europe. */
export const AREA = {
  islandPart: 300,
  forceMerge: 3500,
  absorb: 2000,
  islandAttach: 4000,
  islandAttachKm: 170,
  drop: 1200,
};

export const KEEP_GROUPS = [];

/** Straits an army may cross in one turn, as lon/lat points on either side. */
export const SEA_LINKS = [
  [[-84.73, 45.86], [-84.73, 45.76], 'Straits of Mackinac'],
  [[-55.9, 51.5], [-56.95, 51.45], 'Strait of Belle Isle'],
  [[-63.8, 46.35], [-64.55, 46.2], 'Northumberland Strait'],
  [[-60.4, 46.95], [-59.3, 47.6], 'Cabot Strait'],
  [[-123.9, 49.15], [-123.15, 49.25], 'Strait of Georgia'],
];

/** How far from a coast a sea point may be for the coast to lie on it; a zone's own `reach` overrides it. */
export const SEA_REACH_KM = 450;

/** The sea zones armies are shipped across: a label, points on the water near its coasts, and its neighbours. */
export const SEAS = [
  {
    name: 'Bering Sea',
    label: [-166, 60.5],
    points: [[-165, 60], [-163, 63.8], [-166.5, 62.5], [-162, 58.6], [-165.5, 64.5], [-158, 58.3], [-161, 55.8], [-164.5, 54.6], [-167.5, 53.6], [-159.5, 56.8]],
    links: ['Gulf of Alaska'],
  },
  {
    name: 'Gulf of Alaska',
    label: [-146, 57.2],
    points: [[-150, 59.3], [-146, 60.2], [-141, 59.8], [-137, 58.3], [-134.5, 56.5], [-153, 57], [-157, 56], [-132.5, 54.8]],
    links: ['Bering Sea', 'Pacific Northwest'],
  },
  {
    name: 'Pacific Northwest',
    label: [-128.5, 47.5],
    points: [[-131, 52.5], [-128.5, 50.5], [-126, 49.2], [-124.9, 47.5], [-124.3, 46], [-124.5, 43.5], [-124.5, 41.5], [-123.5, 48.3], [-123.2, 49.2]],
    links: ['Gulf of Alaska', 'California Coast'],
  },
  {
    name: 'California Coast',
    label: [-124, 35],
    points: [[-124.2, 40], [-123.2, 38.2], [-122.2, 36.8], [-121, 35], [-119, 34], [-117.6, 33.2], [-117.2, 32.6], [-116.5, 31.2], [-115.5, 29.5]],
    links: ['Pacific Northwest', 'Gulf of California', 'Mexican Pacific'],
  },
  { name: 'Gulf of California', label: [-111.4, 27.6], points: [[-114.6, 31.2], [-113.3, 30.7], [-112.3, 28.6], [-110.6, 26.6], [-109.6, 24.5], [-111, 27.9], [-109.2, 25.8]], links: ['California Coast', 'Mexican Pacific'] },
  {
    name: 'Mexican Pacific',
    label: [-105.5, 17.2],
    points: [[-112.3, 25.5], [-110, 23], [-106.5, 22.8], [-105.5, 20.5], [-104, 18.8], [-101, 17.3], [-98, 16.1], [-95, 15.9], [-93, 15.5]],
    links: ['California Coast', 'Gulf of California', 'Central American Pacific'],
  },
  {
    name: 'Central American Pacific',
    label: [-87.5, 10.6],
    points: [[-91.5, 14], [-89.5, 13.4], [-88, 13], [-87.3, 12.7], [-86.3, 11.7], [-85.8, 10.3], [-84.5, 9.4], [-82.5, 8], [-80, 7.4], [-79.5, 8.6], [-78.5, 8.2]],
    links: ['Mexican Pacific'],
  },
  {
    name: 'Hudson Bay',
    label: [-86, 59.5],
    points: [[-94, 59], [-92.5, 57.2], [-88.5, 56.3], [-85, 55.4], [-82.5, 55], [-80.5, 52.2], [-79.4, 54.5], [-77, 58], [-78.2, 60.8], [-94, 61.5], [-91, 63.5], [-86, 64.3], [-77.8, 62.3], [-72, 61.5]],
    links: ['Labrador Sea'],
  },
  {
    name: 'Labrador Sea',
    label: [-56.5, 56],
    points: [[-61.5, 56.5], [-59, 54.5], [-57, 53], [-55.5, 52.2], [-62.5, 58.5], [-64.5, 60.3], [-66, 61], [-69, 61.8], [-55.8, 51.6], [-55.4, 50.3], [-53.3, 49.4]],
    links: ['Hudson Bay', 'Gulf of St. Lawrence', 'North Atlantic'],
  },
  {
    name: 'Gulf of St. Lawrence',
    label: [-61.8, 48.4],
    points: [[-66, 49.6], [-68.5, 48.8], [-69.8, 47.8], [-64.3, 48.6], [-62.5, 46.6], [-60.6, 46.9], [-59.3, 48], [-58.2, 49.5], [-60, 50.2], [-57.3, 51.2], [-64.8, 47], [-63, 49.6]],
    links: ['Labrador Sea', 'North Atlantic'],
  },
  {
    name: 'North Atlantic',
    label: [-61, 42.6],
    points: [[-52.8, 47.4], [-55.2, 46.7], [-59.8, 45.9], [-63.4, 44.5], [-65.8, 43.6], [-66.8, 44.6], [-68.5, 44.1], [-70.2, 43.4], [-70.5, 42.1], [-69.9, 41.4], [-71.4, 41.3], [-72.5, 41.1], [-64.5, 45.3]],
    links: ['Labrador Sea', 'Gulf of St. Lawrence', 'Mid-Atlantic'],
  },
  {
    name: 'Mid-Atlantic',
    label: [-71.5, 37.6],
    points: [[-73.6, 40.4], [-74, 39.5], [-74.9, 38.6], [-75.5, 37.6], [-75.4, 36], [-75.8, 35], [-76.6, 34.5], [-76.1, 37.6], [-76.3, 38.6], [-76.4, 39.2], [-72.8, 40.8], [-75.2, 39.2]],
    links: ['North Atlantic', 'South Atlantic'],
  },
  {
    name: 'South Atlantic',
    label: [-77, 29.8],
    points: [[-77.8, 33.8], [-79.3, 32.8], [-80.7, 31.7], [-81.2, 30.2], [-80.4, 28.3], [-79.9, 26.6], [-78, 26.7], [-77.2, 25.3], [-76, 24], [-74.5, 22.6], [-73, 21.3]],
    links: ['Mid-Atlantic', 'Florida Strait', 'Antilles Atlantic'],
  },
  { name: 'Florida Strait', label: [-80.4, 23.6], points: [[-80.2, 25], [-81.6, 24.4], [-82.7, 23.3], [-80.8, 23.2], [-79, 22.6], [-83.6, 23], [-80.1, 25.9]], links: ['South Atlantic', 'Eastern Gulf', 'Western Caribbean'] },
  {
    name: 'Eastern Gulf',
    label: [-86, 26.5],
    points: [[-82.8, 27.8], [-82, 26.5], [-83.5, 29.6], [-85.3, 29.7], [-87.2, 30.2], [-88.5, 30.2], [-89.3, 29.3], [-90.4, 21.4], [-88.8, 21.6], [-87.3, 21.6], [-84.6, 21.9]],
    links: ['Florida Strait', 'Gulf of Mexico', 'Western Caribbean'],
  },
  {
    name: 'Gulf of Mexico',
    label: [-94.5, 25],
    points: [[-91, 29.1], [-93.5, 29.6], [-95, 29.1], [-96.8, 28], [-97.2, 26.2], [-97.6, 24], [-97.6, 22], [-96.6, 19.8], [-95, 18.7], [-93, 18.5], [-91.5, 18.7], [-90.7, 19.7]],
    links: ['Eastern Gulf'],
  },
  {
    name: 'Western Caribbean',
    label: [-81.5, 16.6],
    points: [[-86.8, 20.6], [-87.4, 18.8], [-88, 17.3], [-88.5, 16], [-86.5, 15.9], [-84, 15.2], [-83.3, 13], [-83.5, 10.9], [-82.5, 9.5], [-80, 21.6], [-77.5, 19.8], [-76.2, 19.9], [-78, 18.2], [-76.5, 17.8], [-81.3, 19.3]],
    links: ['Florida Strait', 'Eastern Gulf', 'Eastern Caribbean', 'Antilles Atlantic'],
  },
  {
    name: 'Eastern Caribbean',
    label: [-68.5, 15.5],
    points: [[-74.3, 18.2], [-72.5, 18.1], [-70.5, 18.1], [-68.5, 18.3], [-66.5, 17.8], [-65.3, 18.1], [-61.5, 10.6], [-60.8, 11], [-80, 9.3], [-78.5, 9.5], [-79.5, 9.4]],
    links: ['Western Caribbean', 'Antilles Atlantic'],
  },
  {
    name: 'Antilles Atlantic',
    label: [-70.5, 21.6],
    points: [[-74.6, 20.6], [-72.8, 20.2], [-71, 19.9], [-69, 19.4], [-67.2, 18.6], [-65.8, 18.6], [-76.5, 21.4], [-73, 21.9], [-75.7, 23], [-61, 10.9]],
    links: ['South Atlantic', 'Western Caribbean', 'Eastern Caribbean'],
  },
  { name: 'Lake Superior', reach: 150, label: [-87.6, 47.6], points: [[-92, 46.8], [-90.3, 47], [-88.2, 47.4], [-86.1, 46.6], [-84.8, 46.7], [-87, 48.6], [-89.3, 48.3], [-85.3, 47.8]], links: ['Lake Michigan', 'Lake Huron'] },
  { name: 'Lake Michigan', reach: 150, label: [-87, 43.8], points: [[-87.6, 41.9], [-87.8, 43.4], [-87.5, 44.7], [-86.3, 43.3], [-86.5, 42.2], [-85.7, 45.4], [-87, 45.6], [-86.7, 41.7]], links: ['Lake Superior', 'Lake Huron'] },
  { name: 'Lake Huron', reach: 150, label: [-82.2, 44.8], points: [[-83.4, 44], [-82.5, 43.2], [-82.1, 45.4], [-81.6, 44.4], [-80.3, 44.8], [-83.8, 45.8], [-82, 46.1], [-80.6, 45.7]], links: ['Lake Superior', 'Lake Michigan', 'Lake Erie'] },
  { name: 'Lake Erie', reach: 150, label: [-81.3, 42.2], points: [[-83.2, 41.8], [-82, 41.5], [-80.2, 42.1], [-79.1, 42.7], [-81, 42.6], [-82.5, 42]], links: ['Lake Huron', 'Lake Ontario'] },
  { name: 'Lake Ontario', reach: 150, label: [-77.9, 43.6], points: [[-79.5, 43.5], [-78, 43.3], [-76.6, 43.4], [-77.2, 43.95], [-76.3, 43.9], [-79.2, 43.2]], links: ['Lake Erie'] },
];

/** Province names, where the biggest city's own will not do. */
export const RENAME = {};

/** Close-ups rendered by the build for checking, as fractions of the map: x, y, width, height. */
export const PREVIEWS = {
  'preview_east.png': [0.64, 0.3, 0.3, 0.3],
  'preview_central.png': [0.47, 0.3, 0.3, 0.3],
  'preview_west.png': [0.3, 0.3, 0.3, 0.32],
  'preview_south.png': [0.42, 0.55, 0.45, 0.42],
  'preview_north.png': [0.2, 0, 0.6, 0.35],
};
