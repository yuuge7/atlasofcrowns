// 1914 scenario: who owns which modern admin-1 unit, how hard each modern
// country is merged, capitals, sea links and the wars already running in
// August 1914. Everything here is authored by hand; build_map.mjs consumes it.

/** Map window in lon/lat. Mercator, so this is a rectangle on screen too. */
export const BBOX = { w: -11, s: 29.2, e: 52.5, n: 71.4 };

/** Countries that touch the window but are not part of the game map. */
export const EXCLUDE_ADM0 = ['GRL', 'USA', 'FRO', 'ISL', 'AFG', 'PAK', 'MRT', 'SAH', 'TKM', 'UZB', 'MLI', 'ALD'];

/**
 * `ready` scales the army a nation starts with (default 1): how far it had
 * mobilised by August 1914, and how good that army was.
 */
export const NATIONS = [
  { tag: 'GER', name: 'German Empire', short: 'Germany', color: '#6F6C68', capital: [13.4, 52.52], ready: 1.5 },
  { tag: 'AUS', name: 'Austria-Hungary', short: 'Austria-Hungary', color: '#E3DAC6', capital: [16.37, 48.21], ready: 1.2 },
  { tag: 'RUS', name: 'Russian Empire', short: 'Russia', color: '#4C7D55', capital: [30.3, 59.94], ready: 0.9 },
  { tag: 'OTT', name: 'Ottoman Empire', short: 'Ottomans', color: '#C9A75C', capital: [28.97, 41.01] },
  { tag: 'UKG', name: 'United Kingdom', short: 'Britain', color: '#C9475E', capital: [-0.12, 51.5], ready: 0.8 },
  { tag: 'FRA', name: 'French Republic', short: 'France', color: '#3F6CC4', capital: [2.35, 48.85] },
  { tag: 'ITA', name: 'Kingdom of Italy', short: 'Italy', color: '#86C17A', capital: [12.5, 41.9] },
  { tag: 'SPA', name: 'Kingdom of Spain', short: 'Spain', color: '#E6C744', capital: [-3.7, 40.42] },
  { tag: 'POR', name: 'Portuguese Republic', short: 'Portugal', color: '#2F9C95', capital: [-9.14, 38.72] },
  { tag: 'NET', name: 'Kingdom of the Netherlands', short: 'Netherlands', color: '#EB8B3A', capital: [4.9, 52.37] },
  { tag: 'BEL', name: 'Kingdom of Belgium', short: 'Belgium', color: '#A8743B', capital: [4.35, 50.85] },
  { tag: 'LUX', name: 'Luxembourg', short: 'Luxembourg', color: '#8ED3DD', capital: [6.13, 49.61] },
  { tag: 'SWI', name: 'Swiss Confederation', short: 'Switzerland', color: '#7A2E3A', capital: [7.45, 46.95] },
  { tag: 'DEN', name: 'Kingdom of Denmark', short: 'Denmark', color: '#D98C7A', capital: [12.4, 55.7] },
  { tag: 'NOR', name: 'Kingdom of Norway', short: 'Norway', color: '#7C63B8', capital: [10.75, 59.91] },
  { tag: 'SWE', name: 'Kingdom of Sweden', short: 'Sweden', color: '#5AA9E6', capital: [18.07, 59.33] },
  { tag: 'SER', name: 'Kingdom of Serbia', short: 'Serbia', color: '#B0552F', capital: [20.46, 44.8] },
  { tag: 'MNE', name: 'Kingdom of Montenegro', short: 'Montenegro', color: '#3E4A8A', capital: [19.26, 42.44] },
  { tag: 'ALB', name: 'Principality of Albania', short: 'Albania', color: '#C24A8F', capital: [19.82, 41.33] },
  { tag: 'GRE', name: 'Kingdom of Greece', short: 'Greece', color: '#59B7D9', capital: [23.73, 37.98] },
  { tag: 'BUL', name: 'Tsardom of Bulgaria', short: 'Bulgaria', color: '#7A9A3B', capital: [23.32, 42.7] },
  { tag: 'ROM', name: 'Kingdom of Romania', short: 'Romania', color: '#E3D36A', capital: [26.1, 44.43] },
  { tag: 'PER', name: 'Sublime State of Persia', short: 'Persia', color: '#8F6BB0', capital: [51.39, 35.69] },
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
