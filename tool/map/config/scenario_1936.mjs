// Road to war, July 1936: the Spanish generals have risen against the
// Republic, Germany has marched back into the Rhineland, and Europe drifts
// towards another war. The provinces were drawn for 1914, so the new borders
// follow them where they can: Poland takes Posen, the corridor, Upper Silesia
// and the eastern lands; Romania Transylvania, Bukovina and Bessarabia;
// Czechoslovakia and Yugoslavia stand where Austria-Hungary stood.

import { DEVELOPMENT as DEVELOPMENT_1914 } from './scenario_1914.mjs';

export const SCENARIO_META = {
  id: '1936',
  name: 'Road to war',
  startYear: 1936,
  startMonth: 7,
  // History brings the great war. Each nation's temper (see NATIONS) decides
  // how readily it starts a war of its own: the great powers and most
  // others none at all (0.05 or less), Hungary and Bulgaria now and then.
  aggression: 0.3,
};

export const DEFAULT_READY = 0.6;
export const DEFAULT_TECH = [1, 1];

export const NATIONS = [
  { tag: 'GER', flag: 'h:#000000,#FFFFFF,#DD0000', name: 'German Reich', short: 'Germany', color: '#6F6C68', capital: [13.4, 52.52], ready: 0.8, tech: [3, 3] , aggression: 0.05 },
  { tag: 'FRA', flag: 'v:#0055A4,#FFFFFF,#EF4135', name: 'French Republic', short: 'France', color: '#3F6CC4', capital: [2.35, 48.85], ready: 0.7, tech: [2, 3] , aggression: 0.03 },
  { tag: 'GBR', flag: 'union', name: 'United Kingdom', short: 'Britain', color: '#C9475E', capital: [-0.12, 51.5], ready: 0.6, tech: [2, 3] , aggression: 0.03 },
  { tag: 'ITA', flag: 'v:#009246,#FFFFFF,#CE2B37', name: 'Kingdom of Italy', short: 'Italy', color: '#86C17A', capital: [12.5, 41.9], ready: 0.7, tech: [2, 2] , aggression: 0.05 },
  { tag: 'SOV', flag: 'sun:#CC0000,#FFD700', name: 'Soviet Union', short: 'Soviet Union', color: '#8E3B3B', capital: [37.62, 55.75], ready: 0.8, tech: [2, 2] , aggression: 0.05 },
  { tag: 'POL', flag: 'h:#FFFFFF,#DC143C', name: 'Republic of Poland', short: 'Poland', color: '#D46A6A', capital: [21.01, 52.23], ready: 0.7 , aggression: 0.03 },
  { tag: 'ESR', flag: 'h:#C60B1E,#FFC400,#6D1F7E', name: 'Spanish Republic', short: 'Republic', color: '#E6C744', capital: [-3.7, 40.42], ready: 1.0, tech: [1, 0] , aggression: 0.1 },
  { tag: 'ESN', flag: 'h:#AA151B,#F1BF00,#F1BF00,#AA151B', name: 'Nationalist Spain', short: 'Nationalists', color: '#B5884A', capital: [-5.66, 40.97], ready: 1.0, tech: [1, 0] , aggression: 0.1 },
  { tag: 'POR', flag: 'v:#046A38,#DA291C,#DA291C', name: 'Portuguese Republic', short: 'Portugal', color: '#2F9C95', capital: [-9.14, 38.72] , aggression: 0.03 },
  { tag: 'CZE', flag: 'triangle:#FFFFFF,#D7141A,#11457E', name: 'Czechoslovak Republic', short: 'Czechoslovakia', color: '#5C7FA3', capital: [14.42, 50.08], ready: 0.7, tech: [2, 2] , aggression: 0.03 },
  { tag: 'AUT', flag: 'h:#ED2939,#FFFFFF,#ED2939', name: 'Federal State of Austria', short: 'Austria', color: '#E3DAC6', capital: [16.37, 48.21] , aggression: 0.03 },
  { tag: 'HUN', flag: 'h:#CD2A3E,#FFFFFF,#436F4D', name: 'Kingdom of Hungary', short: 'Hungary', color: '#9C6B4E', capital: [19.04, 47.5] , aggression: 0.15 },
  { tag: 'ROM', flag: 'v:#002B7F,#FCD116,#CE1126', name: 'Kingdom of Romania', short: 'Romania', color: '#E3D36A', capital: [26.1, 44.43] , aggression: 0.03 },
  { tag: 'YUG', flag: 'h:#0C4076,#FFFFFF,#C6363C', name: 'Kingdom of Yugoslavia', short: 'Yugoslavia', color: '#B0552F', capital: [20.46, 44.82] , aggression: 0.03 },
  { tag: 'BUL', flag: 'h:#FFFFFF,#00966E,#D62612', name: 'Tsardom of Bulgaria', short: 'Bulgaria', color: '#7A9A3B', capital: [23.32, 42.7] , aggression: 0.1 },
  { tag: 'GRE', flag: 'greece', name: 'Kingdom of Greece', short: 'Greece', color: '#59B7D9', capital: [23.73, 37.98] , aggression: 0.03 },
  { tag: 'ALB', flag: 'sun:#E41E20,#000000', name: 'Kingdom of Albania', short: 'Albania', color: '#C24A8F', capital: [19.82, 41.33] , aggression: 0.03 },
  { tag: 'TUR', flag: 'crescent:#E30A17,#FFFFFF', name: 'Republic of Turkey', short: 'Turkey', color: '#C9A75C', capital: [32.86, 39.93], tech: [1, 0] , aggression: 0.03 },
  { tag: 'LIT', flag: 'h:#FDB913,#006A44,#C1272D', name: 'Republic of Lithuania', short: 'Lithuania', color: '#C8B040', capital: [23.9, 54.9] , aggression: 0.03 },
  { tag: 'LAT', flag: 'h:#9E3039,#9E3039,#FFFFFF,#9E3039,#9E3039', name: 'Republic of Latvia', short: 'Latvia', color: '#9E3B4B', capital: [24.1, 56.95] , aggression: 0.03 },
  { tag: 'EST', flag: 'h:#0072CE,#000000,#FFFFFF', name: 'Republic of Estonia', short: 'Estonia', color: '#3F86A0', capital: [24.75, 59.44] , aggression: 0.03 },
  { tag: 'FIN', flag: 'nordic:#FFFFFF,#002F6C', name: 'Republic of Finland', short: 'Finland', color: '#D9D4E8', capital: [24.94, 60.17], ready: 0.7 , aggression: 0.03 },
  { tag: 'SWE', flag: 'nordic:#006AA7,#FECC02', name: 'Kingdom of Sweden', short: 'Sweden', color: '#5AA9E6', capital: [18.07, 59.33], tech: [1, 2] , aggression: 0.03 },
  { tag: 'NOR', flag: 'nordic:#BA0C2F,#FFFFFF,#00205B', name: 'Kingdom of Norway', short: 'Norway', color: '#7C63B8', capital: [10.75, 59.91] , aggression: 0.03 },
  { tag: 'DEN', flag: 'nordic:#C8102E,#FFFFFF', name: 'Kingdom of Denmark', short: 'Denmark', color: '#D98C7A', capital: [12.57, 55.68], tech: [1, 2] , aggression: 0.03 },
  { tag: 'NED', flag: 'h:#AE1C28,#FFFFFF,#21468B', name: 'Kingdom of the Netherlands', short: 'Netherlands', color: '#EB8B3A', capital: [4.9, 52.37], tech: [1, 2] , aggression: 0.03 },
  { tag: 'BEL', flag: 'v:#000000,#FDDA24,#EF3340', name: 'Kingdom of Belgium', short: 'Belgium', color: '#A8743B', capital: [4.35, 50.85], tech: [1, 2] , aggression: 0.03 },
  { tag: 'LUX', flag: 'h:#EF3340,#FFFFFF,#00A2E1', name: 'Grand Duchy of Luxembourg', short: 'Luxembourg', color: '#8ED3DD', capital: [6.13, 49.61] , aggression: 0.03 },
  { tag: 'SWI', flag: 'swiss:#DA291C,#FFFFFF', name: 'Swiss Confederation', short: 'Switzerland', color: '#7A2E3A', capital: [7.45, 46.95], tech: [1, 2] , aggression: 0.03 },
  { tag: 'IRL', flag: 'v:#169B62,#FFFFFF,#FF883E', name: 'Irish Free State', short: 'Ireland', color: '#5BAF6B', capital: [-6.26, 53.35] , aggression: 0.03 },
  { tag: 'EGY', flag: 'crescent:#007A3D,#FFFFFF', name: 'Kingdom of Egypt', short: 'Egypt', color: '#D9C27E', capital: [31.24, 30.04], tech: [0, 0] , aggression: 0.03 },
  { tag: 'IRQ', flag: 'triangle:#000000,#FFFFFF,#007A3D,#CE1126', name: 'Kingdom of Iraq', short: 'Iraq', color: '#B9A06A', capital: [44.37, 33.31], tech: [0, 0] , aggression: 0.03 },
  { tag: 'SAU', flag: 'sun:#006C35,#FFFFFF', name: 'Kingdom of Saudi Arabia', short: 'Saudi Arabia', color: '#6E9E62', capital: [39.9, 29.9], tech: [0, 0] , aggression: 0.03 },
  { tag: 'IRN', flag: 'h:#239F40,#FFFFFF,#DA0000', name: 'Imperial State of Iran', short: 'Iran', color: '#8F6BB0', capital: [51.39, 35.69], tech: [0, 0] , aggression: 0.03 },
];

/** Who holds each modern country's land, unless the province says otherwise. */
const BY_GROUP = {
  DEU: 'GER', POL: 'POL', AUT: 'AUT', CZE: 'CZE', SVK: 'CZE', HUN: 'HUN', ROU: 'ROM', MDA: 'ROM', BGR: 'BUL', GRC: 'GRE', ALB: 'ALB',
  SRB: 'YUG', MNE: 'YUG', BIH: 'YUG', HRV: 'YUG', SVN: 'YUG', MKD: 'YUG', ITA: 'ITA', LBY: 'ITA', FRA: 'FRA', DZA: 'FRA', MAR: 'FRA',
  TUN: 'FRA', SYR: 'FRA', LBN: 'FRA', GBR: 'GBR', IRL: 'IRL', CYP: 'GBR', ISR: 'GBR', JOR: 'GBR', KWT: 'GBR', EGY: 'EGY', IRQ: 'IRQ',
  SAU: 'SAU', IRN: 'IRN', TUR: 'TUR', RUS: 'SOV', UKR: 'SOV', BLR: 'SOV', GEO: 'SOV', ARM: 'SOV', AZE: 'SOV', KAZ: 'SOV', LTU: 'LIT',
  LVA: 'LAT', EST: 'EST', FIN: 'FIN', SWE: 'SWE', NOR: 'NOR', DNK: 'DEN', NLD: 'NED', BEL: 'BEL', LUX: 'LUX', CHE: 'SWI', PRT: 'POR',
  ESP: 'ESR',
};

/** Provinces, by their 1914 name on the map, held otherwise than their modern country. */
export const OWNER_BY_PROVINCE = {
  // East Prussia, Silesia and Pomerania were still German.
  Allenstein: 'GER', Breslau: 'GER', Stettin: 'GER', Königsberg: 'GER',
  // Poland's eastern lands.
  Lemberg: 'POL', Rovno: 'POL', 'Brest-Litovsk': 'POL', Grodno: 'POL', Vilna: 'POL',
  // Greater Romania.
  Czernowitz: 'ROM', Dobrich: 'ROM',
  // The rising of July 1936: the Nationalists hold the north-west, Seville, Majorca and Morocco.
  Galicia: 'ESN', Valladolid: 'ESN', Zaragoza: 'ESN', Seville: 'ESN', Balearics: 'ESN', Tetuán: 'ESN',
};

export const ownerOf = (p) => OWNER_BY_PROVINCE[p.name] ?? BY_GROUP[p.modern];

/** Twenty years on, a little richer; the Soviet Union much more industrial. */
const DEVELOPMENT_GAIN = { RUS: 1.5, UKR: 1.4, BLR: 1.3, GEO: 1.3, ARM: 1.3, AZE: 1.3, KAZ: 1.3 };
export const developmentOf = (p) => (DEVELOPMENT_1914[p.modern] ?? 1) * (DEVELOPMENT_GAIN[p.modern] ?? 1.1);

/** Names as they read in 1936, keyed by the 1914 names of the map. */
export const MAP_RENAME = {
  Strassburg: 'Strasbourg', Memel: 'Klaipėda', Posen: 'Poznań', Kattowitz: 'Katowice', Danzig: 'Gdynia', Lemberg: 'Lwów', Vilna: 'Wilno',
  'Brest-Litovsk': 'Brześć', Rovno: 'Równe', Kovno: 'Kaunas', Shavli: 'Šiauliai', Czernowitz: 'Cernăuți', Kishinev: 'Chișinău', Beltsy: 'Bălți',
  Reval: 'Tallinn', Dorpat: 'Tartu', Dvinsk: 'Daugavpils', Libau: 'Liepāja', Helsingfors: 'Helsinki', Kristiania: 'Oslo',
  Constantinople: 'Istanbul', Angora: 'Ankara', Smyrna: 'İzmir', Trebizond: 'Trabzon', Aintab: 'Antep', Agram: 'Zagreb',
  Laibach: 'Ljubljana', Esseg: 'Osijek', Újvidék: 'Novi Sad', Monastir: 'Bitola', Pressburg: 'Bratislava', Kassa: 'Košice',
  Brünn: 'Brno', Ostrau: 'Ostrava', Königgrätz: 'Hradec Králové', Hermannstadt: 'Sibiu', Kolozsvár: 'Cluj', Kronstadt: 'Brașov',
  Nagyvárad: 'Oradea', Temesvár: 'Timișoara', Scutari: 'Shkodër', Trient: 'Trento', Erivan: 'Yerevan', Tiflis: 'Tbilisi',
  Tsaritsyn: 'Stalingrad', Yekaterinoslav: 'Dnipropetrovsk', Yuzovka: 'Stalino', Aleksandrovsk: 'Zaporozhye', Lugansk: 'Voroshilovgrad',
  'Nizhny Novgorod': 'Gorky', Samara: 'Kuybyshev', Vyatka: 'Kirov', 'Ust-Sysolsk': 'Syktyvkar', Petrovsk: 'Makhachkala',
  Yekaterinodar: 'Krasnodar', 'St. Petersburg': 'Leningrad', Vladikavkaz: 'Ordzhonikidze', Kola: 'Murmansk', Dobrich: 'Bazargic',
  Salonica: 'Thessaloniki',
};

export const WARS = [['ESN', 'ESR']];

export const ALLIANCES = [
  // France's eastern allies, and the Franco-Soviet treaty of 1935.
  ['FRA', 'POL'],
  ['FRA', 'CZE'],
  ['SOV', 'CZE'],
  ['FRA', 'SOV'],
  // The Little Entente and the Baltic Entente.
  ['CZE', 'ROM'],
  ['CZE', 'YUG'],
  ['ROM', 'YUG'],
  ['EST', 'LAT'],
  ['LAT', 'LIT'],
  ['EST', 'LIT'],
  // Britain's treaties.
  ['GBR', 'EGY'],
  ['GBR', 'IRQ'],
  ['GBR', 'POR'],
];

/** Non-aggression pacts in force: Germany's with Poland (1934), the Soviet Union's with its western neighbours (1926-32). */
export const PACTS = [
  ['GER', 'POL'],
  ['SOV', 'POL'],
  ['SOV', 'FIN'],
  ['SOV', 'EST'],
  ['SOV', 'LAT'],
  ['SOV', 'LIT'],
];

/** Independence guaranteed, (guarantor, guaranteed): Locarno, and Italy's hand over Austria and Albania. */
export const GUARANTEES = [
  ['GBR', 'BEL'],
  ['ITA', 'BEL'],
  ['FRA', 'LUX'],
  ['ITA', 'AUT'],
  ['ITA', 'ALB'],
];

/** The Maginot Line, the Czechoslovak border forts and the Mannerheim Line, by 1936 name. */
export const FORTS = {
  Strasbourg: 2,
  Nancy: 2,
  'Hradec Králové': 1,
  Brno: 1,
  Viipuri: 2,
};

export const HISTORY = [
  { date: [1936, 10], text: 'Mussolini and Hitler proclaim the Rome–Berlin Axis.', alliances: [['ITA', 'GER']] },
  { date: [1938, 3], text: 'German troops march into Austria.', wars: [['GER', 'AUT']] },
  {
    date: [1938, 9],
    text: 'At Munich, Britain and France give way to Hitler. Czechoslovakia is left alone, and the Little Entente falls apart.',
    breaks: [['FRA', 'CZE'], ['SOV', 'CZE'], ['CZE', 'ROM'], ['CZE', 'YUG']],
  },
  {
    date: [1939, 3],
    text: 'Germany seizes what is left of Czechoslovakia. Britain gives Poland its guarantee.',
    guarantees: [['GBR', 'POL']],
    wars: [['GER', 'CZE']],
  },
  {
    date: [1939, 4],
    text: 'Italy invades Albania. Britain and France guarantee Romania and Greece.',
    guarantees: [['GBR', 'ROM'], ['FRA', 'ROM'], ['GBR', 'GRE'], ['FRA', 'GRE']],
    wars: [['ITA', 'ALB']],
  },
  { date: [1939, 8], text: 'Molotov and Ribbentrop sign a pact of non-aggression between the Soviet Union and Germany.', pacts: [['GER', 'SOV']] },
  { date: [1939, 9], text: 'Germany invades Poland. Britain and France stand by their word.', wars: [['GER', 'POL']] },
  { date: [1939, 11], text: 'The Soviet Union attacks Finland.', wars: [['SOV', 'FIN']] },
  { date: [1940, 4], text: 'Germany invades Denmark and Norway.', wars: [['GER', 'DEN'], ['GER', 'NOR']] },
  { date: [1940, 5], text: 'Germany strikes in the west, through the Low Countries.', wars: [['GER', 'NED'], ['GER', 'BEL'], ['GER', 'LUX']] },
  { date: [1940, 6], text: 'Italy declares war on France and Britain.', wars: [['ITA', 'FRA'], ['ITA', 'GBR']] },
  { date: [1940, 6], text: 'The Soviet Union occupies the Baltic states.', wars: [['SOV', 'EST'], ['SOV', 'LAT'], ['SOV', 'LIT']] },
  { date: [1940, 10], text: 'Italy invades Greece from Albania.', wars: [['ITA', 'GRE']] },
  { date: [1940, 11], text: 'Hungary and Romania join the Axis.', alliances: [['HUN', 'GER'], ['ROM', 'GER']] },
  { date: [1941, 3], text: 'Bulgaria joins the Axis.', alliances: [['BUL', 'GER']] },
  { date: [1941, 4], text: 'Germany invades Yugoslavia and Greece.', wars: [['GER', 'YUG'], ['GER', 'GRE']] },
  {
    date: [1941, 6],
    text: 'Germany tears up its pact and invades the Soviet Union, with Romania, Finland and Hungary at its side.',
    wars: [['GER', 'SOV'], ['ROM', 'SOV'], ['FIN', 'SOV'], ['HUN', 'SOV']],
  },
];
