// 1914 scenario: who owns which modern admin-1 unit, how hard each modern
// country is merged, capitals, sea links and the wars already running in
// August 1914. Everything here is authored by hand; build_map.mjs consumes it.

/** Map window in lon/lat. Mercator, so this is a rectangle on screen too. */
export const BBOX = { w: -11, s: 29.2, e: 52.5, n: 71.4 };

/** Countries that touch the window but are not part of the game map. */
export const EXCLUDE_ADM0 = ['GRL', 'USA', 'FRO', 'ISL', 'AFG', 'PAK', 'MRT', 'SAH', 'TKM', 'UZB', 'MLI', 'ALD'];

/**
 * `ready` scales the army a nation starts with (default 1): how far it had
 * mobilised by August 1914, and how good that army was. `tech` is the
 * starting level in army and industry (default 0, 0).
 */
export const NATIONS = [
  { tag: 'GER', flag: 'h:#000000,#FFFFFF,#DD0000', name: 'German Empire', short: 'Germany', color: '#6F6C68', capital: [13.4, 52.52], ready: 1.5, tech: [2, 2] },
  { tag: 'AUS', flag: 'h:#000000,#FFD200', name: 'Austria-Hungary', short: 'Austria-Hungary', color: '#E3DAC6', capital: [16.37, 48.21], ready: 1.2, tech: [1, 1] },
  { tag: 'RUS', flag: 'h:#FFFFFF,#0039A6,#D52B1E', name: 'Russian Empire', short: 'Russia', color: '#4C7D55', capital: [30.3, 59.94], ready: 0.9 },
  { tag: 'OTT', flag: 'crescent:#E30A17,#FFFFFF', name: 'Ottoman Empire', short: 'Ottomans', color: '#C9A75C', capital: [28.97, 41.01] },
  { tag: 'UKG', flag: 'union', name: 'United Kingdom', short: 'Britain', color: '#C9475E', capital: [-0.12, 51.5], ready: 0.8, tech: [1, 2] },
  { tag: 'FRA', flag: 'v:#0055A4,#FFFFFF,#EF4135', name: 'French Republic', short: 'France', color: '#3F6CC4', capital: [2.35, 48.85], tech: [1, 1] },
  { tag: 'ITA', flag: 'v:#009246,#FFFFFF,#CE2B37', name: 'Kingdom of Italy', short: 'Italy', color: '#86C17A', capital: [12.5, 41.9], tech: [1, 1] },
  { tag: 'SPA', flag: 'h:#AA151B,#F1BF00,#F1BF00,#AA151B', name: 'Kingdom of Spain', short: 'Spain', color: '#E6C744', capital: [-3.7, 40.42] },
  { tag: 'POR', flag: 'v:#046A38,#DA291C,#DA291C', name: 'Portuguese Republic', short: 'Portugal', color: '#2F9C95', capital: [-9.14, 38.72] },
  { tag: 'NET', flag: 'h:#AE1C28,#FFFFFF,#21468B', name: 'Kingdom of the Netherlands', short: 'Netherlands', color: '#EB8B3A', capital: [4.9, 52.37], tech: [0, 1] },
  { tag: 'BEL', flag: 'v:#000000,#FDDA24,#EF3340', name: 'Kingdom of Belgium', short: 'Belgium', color: '#A8743B', capital: [4.35, 50.85], tech: [1, 2] },
  { tag: 'LUX', flag: 'h:#EF3340,#FFFFFF,#00A2E1', name: 'Luxembourg', short: 'Luxembourg', color: '#8ED3DD', capital: [6.13, 49.61], tech: [0, 1] },
  { tag: 'SWI', flag: 'swiss:#DA291C,#FFFFFF', name: 'Swiss Confederation', short: 'Switzerland', color: '#7A2E3A', capital: [7.45, 46.95], tech: [1, 1] },
  { tag: 'DEN', flag: 'nordic:#C8102E,#FFFFFF', name: 'Kingdom of Denmark', short: 'Denmark', color: '#D98C7A', capital: [12.4, 55.7], tech: [0, 1] },
  { tag: 'NOR', flag: 'nordic:#BA0C2F,#FFFFFF,#00205B', name: 'Kingdom of Norway', short: 'Norway', color: '#7C63B8', capital: [10.75, 59.91], tech: [0, 1] },
  { tag: 'SWE', flag: 'nordic:#006AA7,#FECC02', name: 'Kingdom of Sweden', short: 'Sweden', color: '#5AA9E6', capital: [18.07, 59.33], tech: [1, 1] },
  { tag: 'SER', flag: 'h:#C6363C,#0C4076,#FFFFFF', name: 'Kingdom of Serbia', short: 'Serbia', color: '#B0552F', capital: [20.46, 44.8], tech: [1, 0] },
  { tag: 'MNE', flag: 'h:#C6363C,#0C4076,#FFFFFF', name: 'Kingdom of Montenegro', short: 'Montenegro', color: '#3E4A8A', capital: [19.26, 42.44] },
  { tag: 'ALB', flag: 'emblem:#E41E20,#000000', name: 'Principality of Albania', short: 'Albania', color: '#C24A8F', capital: [19.82, 41.33] },
  { tag: 'GRE', flag: 'greece', name: 'Kingdom of Greece', short: 'Greece', color: '#59B7D9', capital: [23.73, 37.98], tech: [1, 0] },
  { tag: 'BUL', flag: 'h:#FFFFFF,#00966E,#D62612', name: 'Tsardom of Bulgaria', short: 'Bulgaria', color: '#7A9A3B', capital: [23.32, 42.7], tech: [1, 0] },
  { tag: 'ROM', flag: 'v:#002B7F,#FCD116,#CE1126', name: 'Kingdom of Romania', short: 'Romania', color: '#E3D36A', capital: [26.1, 44.43] },
  { tag: 'PER', flag: 'h:#239F40,#FFFFFF,#DA0000', name: 'Sublime State of Persia', short: 'Persia', color: '#8F6BB0', capital: [51.39, 35.69] },
];

/** 1914 owner of a modern country, before the per-unit exceptions below. */
const DEFAULT_OWNER = {
  DEU: 'GER',
  AUT: 'AUS', HUN: 'AUS', CZE: 'AUS', SVK: 'AUS', SVN: 'AUS', HRV: 'AUS', BIH: 'AUS', LIE: 'AUS',
  RUS: 'RUS', FIN: 'RUS', EST: 'RUS', LVA: 'RUS', LTU: 'RUS', BLR: 'RUS', UKR: 'RUS', MDA: 'RUS',
  POL: 'RUS', GEO: 'RUS', ARM: 'RUS', AZE: 'RUS', KAZ: 'RUS',
  TUR: 'OTT', SYR: 'OTT', LBN: 'OTT', ISR: 'OTT', PSX: 'OTT', JOR: 'OTT', IRQ: 'OTT', SAU: 'OTT', KWT: 'OTT',
  GBR: 'UKG', IRL: 'UKG', IMN: 'UKG', GGY: 'UKG', JEY: 'UKG', GIB: 'UKG', MLT: 'UKG',
  EGY: 'UKG', CYP: 'UKG', CYN: 'UKG', ESB: 'UKG', WSB: 'UKG',
  FRA: 'FRA', MCO: 'FRA', DZA: 'FRA', TUN: 'FRA', MAR: 'FRA',
  ITA: 'ITA', SMR: 'ITA', VAT: 'ITA', LBY: 'ITA',
  ESP: 'SPA', AND: 'SPA', PRT: 'POR', NLD: 'NET', BEL: 'BEL', LUX: 'LUX', CHE: 'SWI',
  DNK: 'DEN', NOR: 'NOR', SWE: 'SWE',
  SRB: 'SER', KOS: 'SER', MKD: 'SER', MNE: 'MNE', ALB: 'ALB', GRC: 'GRE', BGR: 'BUL', ROU: 'ROM',
  IRN: 'PER',
};

/** Per-unit exceptions, keyed by ISO 3166-2. Modern borders that 1914 cut through. */
const OWNER_BY_ISO = {
  // Alsace-Lorraine
  'FR-57': 'GER', 'FR-67': 'GER', 'FR-68': 'GER',
  // Prussian partition of Poland, Silesia, Pomerania, East Prussia
  'PL-ZP': 'GER', 'PL-PM': 'GER', 'PL-WN': 'GER', 'PL-LB': 'GER', 'PL-WP': 'GER',
  'PL-DS': 'GER', 'PL-OP': 'GER', 'PL-KP': 'GER', 'PL-SL': 'GER',
  'RU-KGD': 'GER', 'LT-KL': 'GER',
  // Galicia
  'PL-MA': 'AUS', 'PL-PK': 'AUS',
  'UA-46': 'AUS', 'UA-26': 'AUS', 'UA-61': 'AUS', 'UA-21': 'AUS', 'UA-77': 'AUS',
  // Transylvania, Banat, Crisana, Maramures, Bukovina
  'RO-AB': 'AUS', 'RO-AR': 'AUS', 'RO-BH': 'AUS', 'RO-BN': 'AUS', 'RO-BV': 'AUS', 'RO-CS': 'AUS',
  'RO-CJ': 'AUS', 'RO-CV': 'AUS', 'RO-HR': 'AUS', 'RO-HD': 'AUS', 'RO-MM': 'AUS', 'RO-MS': 'AUS',
  'RO-SJ': 'AUS', 'RO-SM': 'AUS', 'RO-SB': 'AUS', 'RO-TM': 'AUS', 'RO-SV': 'AUS',
  // Vojvodina
  'RS-01': 'AUS', 'RS-02': 'AUS', 'RS-03': 'AUS', 'RS-04': 'AUS', 'RS-05': 'AUS', 'RS-06': 'AUS', 'RS-07': 'AUS',
  // Trentino, South Tyrol, Austrian Littoral
  'IT-BZ': 'AUS', 'IT-TN': 'AUS', 'IT-TS': 'AUS', 'IT-GO': 'AUS',
  // Kars oblast and Batum, Russian since 1878
  'TR-36': 'RUS', 'TR-75': 'RUS', 'TR-76': 'RUS', 'TR-08': 'RUS',
  // Bulgaria held Western Thrace 1913-1919; Romania took Southern Dobruja in 1913
  'GR-A': 'BUL',
  'BG-08': 'ROM', 'BG-19': 'ROM',
  // Spanish protectorate in Morocco
  'MA-01': 'SPA',
};

/**
 * Units of different modern countries only merge when they share a merge
 * group. Defaults to the modern country itself.
 */
const MERGE_GROUP = {
  AND: 'ESP', MCO: 'FRA', SMR: 'ITA', VAT: 'ITA', LIE: 'AUT', GIB: 'ESP',
  CYN: 'CYP', ESB: 'CYP', WSB: 'CYP', PSX: 'ISR', KOS: 'SRB', IMN: 'GBR',
};

/** Lon/lat boxes wiped before anything else: w, s, e, n. */
export const ERASE_BOXES = [
  [-11, 69.5, -4, 71.4], // Jan Mayen
];

/** Units dropped outright. Mangystau would sit alone across the Caspian. */
const DROP_ISO = ['KZ-MAN'];

/** Returns { owner, group } for one raw admin-1 unit, or null to drop it. */
export function classify(p) {
  if (DROP_ISO.includes(p.iso_3166_2)) return null;
  let owner = OWNER_BY_ISO[p.iso_3166_2] ?? DEFAULT_OWNER[p.adm0_a3];
  let group = MERGE_GROUP[p.adm0_a3] ?? p.adm0_a3;
  // Metohija went to Montenegro in 1913.
  if (p.adm0_a3 === 'KOS' && (p.region === 'Peć' || p.region === 'Đakovica')) {
    owner = 'MNE';
    group = 'MNE';
  }
  if (!owner) return null;
  return { owner, group };
}

/**
 * Province count per merge group. A group split between several 1914 owners
 * shares its count by area, with at least one province per owner.
 */
export const TARGETS = {
  FRA: 20, DEU: 14, ITA: 14, ESP: 14, PRT: 4, GBR: 11, IRL: 4, BEL: 2, NLD: 3, LUX: 1, CHE: 2,
  AUT: 5, CZE: 4, SVK: 2, HUN: 5, POL: 12, DNK: 2, SVN: 1, HRV: 3, BIH: 3, SRB: 6, MNE: 2,
  ALB: 2, MKD: 2, GRC: 8, BGR: 5, ROU: 10, MDA: 2, LTU: 3, LVA: 3, EST: 2, BLR: 6, UKR: 16,
  RUS: 32, KAZ: 2, FIN: 7, SWE: 9, NOR: 7, TUR: 18, GEO: 2, ARM: 1, AZE: 2, SYR: 4, LBN: 1,
  ISR: 2, JOR: 2, IRQ: 6, SAU: 2, KWT: 1, EGY: 5, LBY: 5, TUN: 3, DZA: 9, MAR: 6, IRN: 6, CYP: 1,
};

/** Merge thresholds, km2 of real (spherical) area. */
export const AREA = {
  islandPart: 300, // detached rings smaller than this are deleted outright
  forceMerge: 3500, // units smaller than this always merge into a same-group neighbor
  absorb: 2000, // lone enclaves smaller than this join whoever surrounds them
  islandAttach: 4000, // lone islands smaller than this join the nearest same-group province...
  islandAttachKm: 170, // ...if one lies within this distance
  drop: 1200, // otherwise islands smaller than this vanish
};

/** Groups that must survive even though they are below the absorb threshold. */
export const KEEP_GROUPS = ['LUX'];

/**
 * Sea zones for landings. Every stretch of coast belongs to the zone with the
 * nearest of these points (lon/lat), if one lies within SEA_REACH_KM; an
 * army may sail from its province to any coastal province on the same zone
 * or a neighbouring one. `label` is where the name is lettered on the map.
 * Lake shores (holes in a province) are never coast.
 */
export const SEA_REACH_KM = 420;
export const SEAS = [
  { name: 'Barents Sea', label: [41, 70.4], points: [[38, 70.5], [45, 69.5], [33, 70.2], [50, 69]], links: ['White Sea', 'Norwegian Sea'] },
  { name: 'White Sea', label: [37.5, 65.6], points: [[38, 65.5], [36, 64.6], [40.5, 66.2], [34.8, 66.4]], links: ['Barents Sea'] },
  { name: 'Norwegian Sea', label: [3, 66.5], points: [[5, 63.5], [10, 66.5], [15, 69], [2, 62], [19, 70.4]], links: ['Barents Sea', 'North Sea', 'Atlantic Ocean'] },
  { name: 'North Sea', label: [3.2, 56.2], points: [[3, 56], [2, 53.2], [5, 58.5], [-1, 58.5], [7, 54.5], [0.5, 54], [3.5, 51.8]], links: ['Norwegian Sea', 'Skagerrak', 'English Channel', 'Atlantic Ocean'] },
  { name: 'Skagerrak', label: [9.5, 57.9], points: [[9.5, 57.8], [11.3, 57], [11.8, 56.2], [12.5, 56.1]], links: ['North Sea', 'Baltic Sea'] },
  { name: 'Baltic Sea', label: [18.5, 56.2], points: [[18, 55.5], [15, 55], [20, 57.5], [11, 54.6], [13.5, 54.6], [23.5, 57.8], [21, 55.4], [19, 59]], links: ['Skagerrak', 'Gulf of Bothnia', 'Gulf of Finland'] },
  { name: 'Gulf of Bothnia', label: [20.5, 62.8], points: [[20, 62], [22, 64], [19, 60.8], [23.5, 65.3]], links: ['Baltic Sea'] },
  { name: 'Gulf of Finland', label: [26.5, 59.85], points: [[26, 59.85], [28.5, 59.95], [24, 59.6], [29.8, 60]], links: ['Baltic Sea'] },
  { name: 'English Channel', label: [-2.5, 50.1], points: [[-2, 50.1], [1, 50.6], [-4.5, 49.6], [0, 50.2], [-5.6, 49.8]], links: ['North Sea', 'Atlantic Ocean', 'Bay of Biscay'] },
  { name: 'Irish Sea', label: [-5.1, 53.6], points: [[-5, 53.6], [-4.6, 54.6], [-5.6, 52.2], [-3.8, 53.5], [-5.6, 55.2]], links: ['Atlantic Ocean'] },
  { name: 'Atlantic Ocean', label: [-9.5, 50], points: [[-10, 52], [-10.8, 48], [-10, 40], [-9.8, 37], [-9.9, 33], [-10.3, 30], [-7.5, 57.5], [-6, 59], [-3, 59.2], [-10.5, 54.5]], links: ['Norwegian Sea', 'North Sea', 'English Channel', 'Irish Sea', 'Bay of Biscay', 'Alboran Sea'] },
  { name: 'Bay of Biscay', label: [-4.8, 45.6], points: [[-5, 45.5], [-3, 46.5], [-8, 44], [-2.2, 44.2], [-1.8, 46.8], [-4.5, 48]], links: ['Atlantic Ocean', 'English Channel'] },
  { name: 'Alboran Sea', label: [-3.6, 35.95], points: [[-3.5, 36], [-5, 35.9], [-1.5, 35.8], [-4.5, 36.5], [-2.5, 36.6]], links: ['Atlantic Ocean', 'Balearic Sea'] },
  { name: 'Balearic Sea', label: [4.6, 38.9], points: [[2, 38.5], [5, 40], [4, 37.5], [1, 36.8], [3.8, 42.6], [7, 37.4], [0.5, 39.6], [5.5, 43]], links: ['Alboran Sea', 'Ligurian Sea', 'Tyrrhenian Sea', 'Strait of Sicily'] },
  { name: 'Ligurian Sea', label: [8.6, 43.5], points: [[8.5, 43.7], [7.3, 43.4], [10, 43.7], [9.5, 43.1]], links: ['Balearic Sea', 'Tyrrhenian Sea'] },
  { name: 'Tyrrhenian Sea', label: [12, 39.8], points: [[12, 40.5], [11, 39], [13.5, 39.5], [10.6, 42.3], [14.8, 40.3], [15.8, 38.8], [13, 38.3], [9.8, 41]], links: ['Balearic Sea', 'Ligurian Sea', 'Strait of Sicily', 'Ionian Sea'] },
  { name: 'Adriatic Sea', label: [15.3, 43.1], points: [[15, 43], [13, 44.5], [17, 42], [18.5, 41.3], [12.6, 45.4], [14, 45], [16.3, 41.5]], links: ['Ionian Sea'] },
  { name: 'Ionian Sea', label: [18.9, 37.2], points: [[18, 38], [20.2, 37.4], [16.6, 37.6], [19.6, 39.6], [21.3, 36.8], [17.3, 39.7]], links: ['Adriatic Sea', 'Tyrrhenian Sea', 'Strait of Sicily', 'Aegean Sea', 'Levantine Sea'] },
  { name: 'Strait of Sicily', label: [14.3, 34.6], points: [[12, 35.5], [15, 34], [18, 32.2], [11.2, 36.9], [20, 31.6], [11, 33.6], [14.3, 36.5], [13, 33.2], [16, 31.3]], links: ['Balearic Sea', 'Tyrrhenian Sea', 'Ionian Sea', 'Levantine Sea'] },
  { name: 'Aegean Sea', label: [25, 38.7], points: [[25, 38.5], [24.4, 40.2], [26, 37], [25.2, 35.5], [23.4, 37.6], [26.6, 39.3], [27.7, 36.6], [23, 39.5], [25.8, 40.6], [26.2, 40.1]], links: ['Ionian Sea', 'Levantine Sea', 'Sea of Marmara'] },
  { name: 'Sea of Marmara', label: [28.1, 40.75], points: [[28, 40.75], [27.6, 40.65], [29, 40.7]], links: ['Aegean Sea', 'Black Sea'] },
  { name: 'Levantine Sea', label: [29.6, 33.5], points: [[30, 33.5], [33, 34.5], [34.5, 32.5], [28, 34.6], [25, 33.2], [35.4, 35.5], [31, 31.7], [32.5, 36.2], [29.5, 36]], links: ['Ionian Sea', 'Strait of Sicily', 'Aegean Sea', 'Red Sea'] },
  { name: 'Black Sea', label: [34.2, 43.4], points: [[34, 43.5], [31, 43], [37, 44], [39.5, 41.5], [30.5, 45.5], [36.5, 46], [41.2, 42], [33, 44.7], [29, 41.4], [35, 42.3]], links: ['Sea of Marmara'] },
  { name: 'Red Sea', label: [33.4, 29.7], points: [[33, 29], [32.6, 29.6], [34.8, 29.2], [33.7, 28.6]], links: ['Levantine Sea'] },
  { name: 'Persian Gulf', label: [49.3, 29.5], points: [[49.5, 29.4], [48.6, 29.8], [50.5, 29], [48.4, 29.4]], links: [] },
  { name: 'Caspian Sea', label: [50.2, 42.3], points: [[50, 42], [51, 45], [51.5, 40], [49.5, 38], [50.5, 37], [49, 46], [48, 43.5], [52, 41.5]], links: [] },
];

/**
 * Sea crossings, as lon/lat points that must fall inside the two provinces.
 * Armies move across these exactly like a land border.
 */
export const SEA_LINKS = [
  [[1.0, 51.2], [2.3, 50.6], 'Dover - Calais'],
  [[-6.0, 54.7], [-4.6, 55.1], 'North Channel'],
  [[-3.9, 52.9], [-6.5, 53.2], 'Irish Sea'],
  [[10.4, 55.3], [11.7, 55.4], 'Great Belt'],
  [[12.3, 55.8], [13.4, 55.8], 'Oresund'],
  [[18.3, 59.7], [22.6, 60.6], 'Aland Sea'],
  [[24.9, 59.3], [25.0, 60.4], 'Gulf of Finland'],
  [[15.2, 38.0], [16.1, 38.4], 'Strait of Messina'],
  [[12.7, 37.8], [10.6, 36.7], 'Strait of Sicily'],
  [[9.1, 40.8], [9.1, 41.8], 'Strait of Bonifacio'],
  [[9.3, 42.5], [10.9, 43.2], 'Corsica - Tuscany'],
  [[9.0, 42.3], [6.3, 43.4], 'Corsica - Provence'],
  [[2.9, 39.6], [-0.6, 39.4], 'Balearic Sea'],
  [[2.9, 39.6], [2.0, 41.6], 'Balearics - Catalonia'],
  [[-5.7, 36.4], [-5.5, 35.4], 'Strait of Gibraltar'],
  [[24.8, 35.2], [22.4, 37.2], 'Sea of Crete'],
  [[26.2, 39.2], [27.5, 39.3], 'Lesbos - Anatolia'],
  [[28.0, 36.2], [28.6, 37.1], 'Rhodes - Anatolia'],
  [[24.8, 35.2], [25.5, 37.05], 'Crete - Cyclades'],
  [[33.2, 35.0], [33.6, 36.5], 'Cyprus - Cilicia'],
  [[33.2, 35.0], [36.2, 35.3], 'Cyprus - Levant'],
  [[36.2, 45.3], [37.4, 45.2], 'Kerch Strait'],
  [[18.1, 40.3], [19.8, 40.6], 'Strait of Otranto'],
];

/** Wars already declared when the scenario opens (August 1914). */
export const WARS = [
  ['GER', 'FRA'], ['GER', 'RUS'], ['GER', 'UKG'], ['GER', 'BEL'], ['GER', 'SER'], ['GER', 'MNE'],
  ['AUS', 'RUS'], ['AUS', 'SER'], ['AUS', 'MNE'], ['AUS', 'FRA'], ['AUS', 'UKG'], ['AUS', 'BEL'],
];

/**
 * Alliances in force when the scenario opens. The Entente and its Balkan
 * protégés, the Dual Alliance, and the secret Ottoman-German treaty of
 * 2 August 1914. Italy and Romania had stayed out of their treaties.
 */
export const ALLIANCES = [
  ['FRA', 'RUS'], ['FRA', 'UKG'], ['RUS', 'UKG'], ['UKG', 'BEL'], ['FRA', 'BEL'],
  ['RUS', 'SER'], ['SER', 'MNE'], ['UKG', 'POR'],
  ['GER', 'AUS'], ['GER', 'OTT'],
];

/**
 * The war as it went: who joined, and when. Each event is replayed in its
 * month if it still makes sense then (both sides standing, not already at
 * war or allied). A player's nation is never made to declare war; it is
 * offered the alliance instead.
 */
export const HISTORY = [
  {
    date: [1914, 11],
    text: 'The Ottoman fleet shells Odessa. The Ottoman Empire enters the war against Russia.',
    wars: [['OTT', 'RUS']],
  },
  {
    date: [1915, 5],
    text: 'Bound by the secret Treaty of London, Italy joins the Entente and declares war on Austria-Hungary.',
    alliances: [['ITA', 'FRA'], ['ITA', 'UKG'], ['ITA', 'RUS']],
    wars: [['ITA', 'AUS']],
  },
  {
    date: [1915, 10],
    text: 'Bulgaria joins the Central Powers and invades Serbia.',
    alliances: [['BUL', 'GER'], ['BUL', 'AUS'], ['BUL', 'OTT']],
    wars: [['BUL', 'SER']],
  },
  {
    date: [1916, 3],
    text: 'Lisbon seizes the German ships in its harbours. Germany declares war on Portugal.',
    wars: [['GER', 'POR']],
  },
  {
    date: [1916, 8],
    text: 'Romania joins the Entente and marches into Transylvania.',
    alliances: [['ROM', 'FRA'], ['ROM', 'RUS']],
    wars: [['ROM', 'AUS']],
  },
  {
    date: [1917, 6],
    text: 'Greece, united under Venizelos, joins the Entente.',
    alliances: [['GRE', 'FRA'], ['GRE', 'UKG']],
    wars: [['GRE', 'BUL']],
  },
];

/**
 * Fortresses standing in August 1914, by 1914 province name: level 2 for
 * the great ring fortresses, 1 for the rest. Verdun and Toul sit in Nancy,
 * Metz in Strassburg, Przemyśl in Lemberg, Novogeorgievsk in Warsaw.
 */
export const FORTS = {
  Nancy: 2, Reims: 1, Besançon: 1, Lille: 1, Paris: 1,
  Liège: 2, Brussels: 1,
  Strassburg: 2, Königsberg: 1, Posen: 1, Mainz: 1,
  Lemberg: 2, Kraków: 1, Trient: 1,
  Warsaw: 1, Kovno: 1, 'Brest-Litovsk': 1, Kars: 1, 'St. Petersburg': 1,
  Constantinople: 2, Venice: 1, Belgrade: 1, Bucharest: 1,
};

/**
 * How developed a modern country's territory was in 1914, relative to the
 * European average. Scales province income; modern population alone would
 * make Cairo and Baghdad outweigh the Ruhr.
 */
export const DEVELOPMENT = {
  GBR: 1.7, DEU: 1.8, BEL: 1.6, NLD: 1.5, CHE: 1.5, LUX: 1.5, FRA: 1.4, DNK: 1.3, SWE: 1.2, NOR: 1.1,
  AUT: 1.3, CZE: 1.3, HUN: 1.0, SVK: 0.9, SVN: 1.0, HRV: 0.8, BIH: 0.6, ITA: 1.0, IRL: 0.9,
  ESP: 0.8, PRT: 0.7, POL: 0.9, FIN: 0.8, EST: 0.8, LVA: 0.9, LTU: 0.7, BLR: 0.5, UKR: 0.6,
  RUS: 0.5, MDA: 0.5, GEO: 0.5, ARM: 0.5, AZE: 0.6, KAZ: 0.4,
  ROU: 0.7, BGR: 0.7, SRB: 0.7, MKD: 0.6, MNE: 0.6, ALB: 0.5, GRC: 0.7, CYP: 0.5,
  TUR: 0.45, SYR: 0.4, LBN: 0.5, ISR: 0.4, JOR: 0.3, IRQ: 0.35, SAU: 0.3, KWT: 0.3,
  EGY: 0.4, LBY: 0.3, TUN: 0.4, DZA: 0.4, MAR: 0.35, IRN: 0.35,
};

/** Province names as they read in 1914, keyed by the generated name. */
export const RENAME = {
  // German Empire
  Bremen: 'Hanover', Saarbrücken: 'Mainz', Strasbourg: 'Strassburg', Klaipėda: 'Memel', Poznań: 'Posen',
  Olsztyn: 'Allenstein', Szczecin: 'Stettin', Katowice: 'Kattowitz', Wrocław: 'Breslau', Gdańsk: 'Danzig',
  Kaliningrad: 'Königsberg',
  // Austria-Hungary
  Lviv: 'Lemberg', Chernivtsi: 'Czernowitz', Bratislava: 'Pressburg', Košice: 'Kassa', 'Cluj-Napoca': 'Kolozsvár',
  Brașov: 'Kronstadt', Sibiu: 'Hermannstadt', Timișoara: 'Temesvár', Oradea: 'Nagyvárad', 'Novi Sad': 'Újvidék',
  Zagreb: 'Agram', Ljubljana: 'Laibach', Trento: 'Trient', Brno: 'Brünn', Ostrava: 'Ostrau',
  Pardubice: 'Königgrätz', 'Slavonski Brod': 'Esseg', Miskolc: 'Debrecen',
  // Russian Empire
  Tallinn: 'Reval', Tartu: 'Dorpat', Helsinki: 'Helsingfors', Vilnius: 'Vilna', Kaunas: 'Kovno', Šiauliai: 'Shavli',
  Daugavpils: 'Dvinsk', Liepaga: 'Libau', Chișinău: 'Kishinev', Bălți: 'Beltsy', Homyel: 'Gomel', Hrodna: 'Grodno',
  Vitsyebsk: 'Vitebsk', Mahilyow: 'Mogilev', Brest: 'Brest-Litovsk', Tbilisi: 'Tiflis', Yerevan: 'Erivan',
  Naxcivan: 'Nakhichevan', Oral: 'Uralsk', Atyrau: 'Guryev', Kirov: 'Vyatka', Volgograd: 'Tsaritsyn',
  Krasnodar: 'Yekaterinodar', Makhachkala: 'Petrovsk', 'Velikiy Novgorod': 'Novgorod', Syktyvkar: 'Ust-Sysolsk',
  Cherepovets: 'Vologda', Bugrino: 'Pechora', Murmansk: 'Kola', Archangel: 'Arkhangelsk', Dnipro: 'Yekaterinoslav',
  Donetsk: 'Yuzovka', Luhansk: 'Lugansk', Kyiv: 'Kiev', Kharkiv: 'Kharkov', Mykolayiv: 'Nikolayev',
  Khmelnytskyy: 'Proskurov', Zaporizhzhya: 'Aleksandrovsk', Rivne: 'Rovno', Chernihiv: 'Chernigov',
  Zhytomyr: 'Zhitomir', Cherkasy: 'Cherkassy', Sevastopol: 'Crimea', Lappeenranta: 'Viipuri', Elista: 'Kalmykia',
  // Ottoman Empire
  Istanbul: 'Constantinople', İzmir: 'Smyrna', Ankara: 'Angora', Trabzon: 'Trebizond', Gaziantep: 'Aintab',
  Batman: 'Mardin', Corum: 'Çorum', Zonguldak: 'Kastamonu', Tarsus: 'Mersin', 'Tel Aviv': 'Jerusalem',
  'Gaza City': 'Gaza', 'Al Aqabah': 'Aqaba', 'Ar Ramadi': 'Ramadi', Irbil: 'Erbil', 'Dayr az Zawr': 'Deir ez-Zor',
  Sakakah: 'Al Jawf', 'Kuwait City': 'Kuwait',
  // British Empire
  'Southend-on-Sea': 'Norwich', Dundalk: 'Sligo', Nicosia: 'Cyprus', Matruh: 'Mersa Matruh', Ismaïlia: 'Suez',
  'El Arish': 'Sinai',
  // France and its North Africa
  Aveyron: 'Rodez', Poitier: 'Poitiers', Biarritz: 'Bayonne', Ajaccio: 'Corsica', Marrakesh: 'Marrakech',
  // Italy and Libya
  Palermo: 'Sicily', Cagliari: 'Sardinia', Verona: 'Venice', 'Reggio di Calabria': 'Calabria', Salerno: 'Apulia',
  Banghazi: 'Benghazi', 'Az Zawiyah': 'Zawiya', Tubruq: 'Tobruk', Nalut: 'Ghadames',
  // Iberia
  Palma: 'Balearics', Castello: 'Castellón', Tangier: 'Tetuán', Portimão: 'Faro', Vigo: 'Galicia',
  // Low Countries, Alps, Scandinavia
  'The Hague': 'Amsterdam', Geneva: 'Bern', København: 'Copenhagen', Århus: 'Aarhus', Oslo: 'Kristiania',
  Göteborg: 'Gothenburg',
  // Balkans
  Thessaloniki: 'Salonica', Ioanina: 'Ioannina', Chalkida: 'Chalcis', Patra: 'Patras', Iraklio: 'Crete',
  Pec: 'Peć', Shkodër: 'Scutari', Podgorica: 'Cetinje', Bitola: 'Monastir',
};

export const SCENARIO_META = {
  id: '1914',
  name: 'The Great War',
  startYear: 1914,
  startMonth: 8,
};
