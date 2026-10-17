// Europe today: the same provinces, owned by the countries that hold them
// now. Every province already belongs to one modern country (its merge
// group), so the borders fit exactly, except where a group mixes two
// countries at this scale: those few provinces are assigned by hand below.
// No wars are running when the scenario opens.

export const SCENARIO_META = {
  id: 'modern',
  name: 'Europe today',
  startYear: 2026,
  startMonth: 1,
  // The AI starts wars a thirtieth as often as in 1914: the player sets the
  // pace of this one.
  aggression: 0.03,
};

/**
 * `ready` scales the standing army against a full mobilisation (default
 * 0.7, peacetime); `tech` is the starting level in army and industry
 * (default 1, 1).
 */
export const NATIONS = [
  { tag: 'RUS', name: 'Russian Federation', short: 'Russia', color: '#4C7D55', capital: [37.62, 55.75], ready: 1.0, tech: [3, 1] },
  { tag: 'DEU', name: 'Federal Republic of Germany', short: 'Germany', color: '#6F6C68', capital: [13.4, 52.52], tech: [2, 4] },
  { tag: 'FRA', name: 'French Republic', short: 'France', color: '#3F6CC4', capital: [2.35, 48.85], tech: [3, 3] },
  { tag: 'GBR', name: 'United Kingdom', short: 'Britain', color: '#C9475E', capital: [-0.12, 51.5], tech: [3, 3] },
  { tag: 'ITA', name: 'Italian Republic', short: 'Italy', color: '#86C17A', capital: [12.5, 41.9], tech: [2, 3] },
  { tag: 'ESP', name: 'Kingdom of Spain', short: 'Spain', color: '#E6C744', capital: [-3.7, 40.42], tech: [2, 3] },
  { tag: 'PRT', name: 'Portuguese Republic', short: 'Portugal', color: '#2F9C95', capital: [-9.14, 38.72], tech: [1, 2] },
  { tag: 'NLD', name: 'Kingdom of the Netherlands', short: 'Netherlands', color: '#EB8B3A', capital: [4.9, 52.37], tech: [2, 4] },
  { tag: 'BEL', name: 'Kingdom of Belgium', short: 'Belgium', color: '#A8743B', capital: [4.35, 50.85], tech: [2, 3] },
  { tag: 'LUX', name: 'Grand Duchy of Luxembourg', short: 'Luxembourg', color: '#8ED3DD', capital: [6.13, 49.61], tech: [1, 4] },
  { tag: 'CHE', name: 'Swiss Confederation', short: 'Switzerland', color: '#7A2E3A', capital: [7.45, 46.95], tech: [2, 4] },
  { tag: 'AUT', name: 'Republic of Austria', short: 'Austria', color: '#E3DAC6', capital: [16.37, 48.21], tech: [1, 3] },
  { tag: 'IRL', name: 'Ireland', short: 'Ireland', color: '#5BAF6B', capital: [-6.26, 53.35], tech: [0, 4] },
  { tag: 'DNK', name: 'Kingdom of Denmark', short: 'Denmark', color: '#D98C7A', capital: [12.57, 55.68], tech: [2, 3] },
  { tag: 'NOR', name: 'Kingdom of Norway', short: 'Norway', color: '#7C63B8', capital: [10.75, 59.91], tech: [2, 3] },
  { tag: 'SWE', name: 'Kingdom of Sweden', short: 'Sweden', color: '#5AA9E6', capital: [18.07, 59.33], tech: [3, 3] },
  { tag: 'FIN', name: 'Republic of Finland', short: 'Finland', color: '#D9D4E8', capital: [24.94, 60.17], ready: 0.9, tech: [3, 3] },
  { tag: 'EST', name: 'Republic of Estonia', short: 'Estonia', color: '#3F86A0', capital: [24.75, 59.44], tech: [2, 2] },
  { tag: 'LVA', name: 'Republic of Latvia', short: 'Latvia', color: '#9E3B4B', capital: [24.11, 56.95], tech: [1, 2] },
  { tag: 'LTU', name: 'Republic of Lithuania', short: 'Lithuania', color: '#C8B040', capital: [25.28, 54.69], tech: [1, 2] },
  { tag: 'POL', name: 'Republic of Poland', short: 'Poland', color: '#D46A6A', capital: [21.01, 52.23], ready: 0.9, tech: [2, 2] },
  { tag: 'CZE', name: 'Czech Republic', short: 'Czechia', color: '#5C7FA3', capital: [14.42, 50.08], tech: [1, 3] },
  { tag: 'SVK', name: 'Slovak Republic', short: 'Slovakia', color: '#B5A0C8', capital: [17.11, 48.15], tech: [1, 2] },
  { tag: 'HUN', name: 'Hungary', short: 'Hungary', color: '#9C6B4E', capital: [19.04, 47.5], tech: [1, 2] },
  { tag: 'SVN', name: 'Republic of Slovenia', short: 'Slovenia', color: '#78B4A0', capital: [14.51, 46.06], tech: [1, 3] },
  { tag: 'HRV', name: 'Republic of Croatia', short: 'Croatia', color: '#D05050', capital: [15.98, 45.81], tech: [1, 2] },
  { tag: 'BIH', name: 'Bosnia and Herzegovina', short: 'Bosnia', color: '#6A8FC0', capital: [18.41, 43.86], tech: [0, 1] },
  { tag: 'SRB', name: 'Republic of Serbia', short: 'Serbia', color: '#B0552F', capital: [20.46, 44.8], tech: [1, 1] },
  { tag: 'MNE', name: 'Montenegro', short: 'Montenegro', color: '#3E4A8A', capital: [19.26, 42.44], tech: [1, 1] },
  { tag: 'KOS', name: 'Republic of Kosovo', short: 'Kosovo', color: '#D6A84C', capital: [21.17, 42.67], tech: [0, 1] },
  { tag: 'ALB', name: 'Republic of Albania', short: 'Albania', color: '#C24A8F', capital: [19.82, 41.33], tech: [1, 1] },
  { tag: 'MKD', name: 'North Macedonia', short: 'N. Macedonia', color: '#E07040', capital: [21.43, 42.0], tech: [1, 1] },
  { tag: 'GRC', name: 'Hellenic Republic', short: 'Greece', color: '#59B7D9', capital: [23.73, 37.98], ready: 0.9, tech: [2, 2] },
  { tag: 'BGR', name: 'Republic of Bulgaria', short: 'Bulgaria', color: '#7A9A3B', capital: [23.32, 42.7], tech: [1, 1] },
  { tag: 'ROU', name: 'Romania', short: 'Romania', color: '#E3D36A', capital: [26.1, 44.43], tech: [1, 2] },
  { tag: 'MDA', name: 'Republic of Moldova', short: 'Moldova', color: '#B07AA8', capital: [28.86, 47.01], tech: [0, 0] },
  { tag: 'UKR', name: 'Ukraine', short: 'Ukraine', color: '#7FB2E0', capital: [30.52, 50.45], ready: 1.2, tech: [3, 1] },
  { tag: 'BLR', name: 'Republic of Belarus', short: 'Belarus', color: '#8FA86A', capital: [27.56, 53.9], tech: [1, 0] },
  { tag: 'GEO', name: 'Georgia', short: 'Georgia', color: '#C05A7A', capital: [44.79, 41.72], tech: [1, 0] },
  { tag: 'ARM', name: 'Republic of Armenia', short: 'Armenia', color: '#E39B56', capital: [44.51, 40.18], tech: [1, 0] },
  { tag: 'AZE', name: 'Republic of Azerbaijan', short: 'Azerbaijan', color: '#5FA8A0', capital: [49.87, 40.41], tech: [1, 1] },
  { tag: 'KAZ', name: 'Republic of Kazakhstan', short: 'Kazakhstan', color: '#9CC6B4', capital: [51.37, 51.23], tech: [1, 1] },
  { tag: 'TUR', name: 'Republic of Türkiye', short: 'Türkiye', color: '#C9A75C', capital: [32.85, 39.93], ready: 0.9, tech: [3, 2] },
  { tag: 'CYP', name: 'Republic of Cyprus', short: 'Cyprus', color: '#E8A050', capital: [33.36, 35.17], tech: [1, 2] },
  { tag: 'SYR', name: 'Syrian Arab Republic', short: 'Syria', color: '#A35E5E', capital: [36.29, 33.51], tech: [0, 0] },
  { tag: 'LBN', name: 'Lebanese Republic', short: 'Lebanon', color: '#E3C2B0', capital: [35.5, 33.89], tech: [0, 0] },
  { tag: 'ISR', name: 'State of Israel', short: 'Israel', color: '#7C9CC4', capital: [34.85, 32.0], ready: 1.0, tech: [4, 3] },
  { tag: 'PSE', name: 'State of Palestine', short: 'Palestine', color: '#5B8C5A', capital: [34.45, 31.5], tech: [0, 0] },
  { tag: 'JOR', name: 'Hashemite Kingdom of Jordan', short: 'Jordan', color: '#D8B06A', capital: [35.93, 31.95], tech: [1, 1] },
  { tag: 'IRQ', name: 'Republic of Iraq', short: 'Iraq', color: '#B9A06A', capital: [44.36, 33.31], tech: [1, 0] },
  { tag: 'KWT', name: 'State of Kuwait', short: 'Kuwait', color: '#C6A0A0', capital: [47.98, 29.37], tech: [1, 2] },
  { tag: 'SAU', name: 'Kingdom of Saudi Arabia', short: 'Saudi Arabia', color: '#6E9E62', capital: [40.2, 29.97], tech: [2, 1] },
  { tag: 'IRN', name: 'Islamic Republic of Iran', short: 'Iran', color: '#8F6BB0', capital: [51.39, 35.69], ready: 0.9, tech: [2, 0] },
  { tag: 'EGY', name: 'Arab Republic of Egypt', short: 'Egypt', color: '#D9C27E', capital: [31.24, 30.04], ready: 0.8, tech: [1, 0] },
  { tag: 'LBY', name: 'State of Libya', short: 'Libya', color: '#9AB37A', capital: [13.19, 32.89], tech: [0, 0] },
  { tag: 'TUN', name: 'Republic of Tunisia', short: 'Tunisia', color: '#C46E5A', capital: [10.18, 36.81], tech: [0, 1] },
  { tag: 'DZA', name: "People's Democratic Republic of Algeria", short: 'Algeria', color: '#6B9E78', capital: [3.06, 36.75], tech: [1, 0] },
  { tag: 'MAR', name: 'Kingdom of Morocco', short: 'Morocco', color: '#B5584A', capital: [-6.84, 34.02], tech: [1, 0] },
];

/** Default `ready` and `tech` for nations that do not set them. */
export const DEFAULT_READY = 0.7;
export const DEFAULT_TECH = [1, 1];

/**
 * Owners by 1914 province name, where a merge group spans two countries.
 * Kosovo was merged into Serbia and Montenegro; Israel's two provinces
 * each mix Israeli and Palestinian land, and the one around Gaza goes to
 * Palestine.
 */
export const OWNER_BY_PROVINCE = {
  Pristina: 'KOS',
  'Peć': 'KOS',
  Gaza: 'PSE',
};

/** How developed each country is today, relative to the European average. */
export const DEVELOPMENT = {
  LUX: 2.6, CHE: 2.2, NOR: 2.2, IRL: 2.0, DNK: 1.9, NLD: 1.9, DEU: 1.8, SWE: 1.8, AUT: 1.8, BEL: 1.7,
  FIN: 1.6, GBR: 1.6, FRA: 1.6, ISR: 1.5, ITA: 1.4, KWT: 1.4, ESP: 1.3, CZE: 1.3, SVN: 1.3, EST: 1.2,
  PRT: 1.1, LTU: 1.1, POL: 1.1, CYP: 1.2, SVK: 1.0, HUN: 1.0, LVA: 1.0, HRV: 1.0, GRC: 1.0, SAU: 1.0,
  ROU: 0.9, BGR: 0.8, RUS: 0.8, TUR: 0.8, KAZ: 0.8, SRB: 0.7, MNE: 0.7, BLR: 0.6, MKD: 0.6, ALB: 0.6,
  BIH: 0.6, GEO: 0.6, ARM: 0.6, AZE: 0.6, UKR: 0.5, MDA: 0.5, IRN: 0.5, IRQ: 0.5, DZA: 0.5, LBY: 0.5,
  JOR: 0.5, EGY: 0.4, TUN: 0.5, MAR: 0.4, LBN: 0.4, SYR: 0.25, KOS: 0.5, PSE: 0.3,
};

/** NATO members on the map, all bound to each other. */
const NATO = [
  'ALB', 'BEL', 'BGR', 'HRV', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', 'HUN', 'ITA', 'LVA', 'LTU',
  'LUX', 'MNE', 'NLD', 'MKD', 'NOR', 'POL', 'PRT', 'ROU', 'SVK', 'SVN', 'ESP', 'SWE', 'TUR', 'GBR',
];

export const ALLIANCES = [
  ...NATO.flatMap((a, i) => NATO.slice(i + 1).map((b) => [a, b])),
  ['RUS', 'BLR'], ['RUS', 'KAZ'],
];

export const WARS = [];

export const FORTS = {};

/**
 * Province names for today, keyed by the generated name (the largest city
 * in its own spelling). Only names the generator gets wrong or that read
 * badly in English; the rest stand as generated.
 */
export const RENAME = {
  'Southend-on-Sea': 'Norwich', Matruh: 'Mersa Matruh', Ismaïlia: 'Suez', 'El Arish': 'Sinai',
  Aveyron: 'Rodez', Poitier: 'Poitiers', Biarritz: 'Bayonne', Ajaccio: 'Corsica', Marrakesh: 'Marrakech',
  Palermo: 'Sicily', Cagliari: 'Sardinia', Verona: 'Venice', 'Reggio di Calabria': 'Calabria', Salerno: 'Apulia',
  Banghazi: 'Benghazi', 'Az Zawiyah': 'Zawiya', Tubruq: 'Tobruk', Nalut: 'Ghadames',
  Palma: 'Balearics', Castello: 'Castellón', Portimão: 'Faro', Vigo: 'Galicia',
  'The Hague': 'Amsterdam', Geneva: 'Bern', København: 'Copenhagen', Århus: 'Aarhus', Göteborg: 'Gothenburg',
  Iraklio: 'Crete', Ioanina: 'Ioannina', Patra: 'Patras', Pec: 'Peć',
  'Gaza City': 'Gaza', 'Al Aqabah': 'Aqaba', 'Ar Ramadi': 'Ramadi', Irbil: 'Erbil', 'Dayr az Zawr': 'Deir ez-Zor',
  Sakakah: 'Al Jawf', 'Kuwait City': 'Kuwait', Corum: 'Çorum', Tarsus: 'Mersin',
  Liepaga: 'Liepāja', Naxcivan: 'Nakhchivan', Homyel: 'Homel', Vitsyebsk: 'Vitebsk', Mahilyow: 'Mogilev',
  Khmelnytskyy: 'Khmelnytskyi', Zaporizhzhya: 'Zaporizhzhia', Mykolayiv: 'Mykolaiv', Sevastopol: 'Crimea',
  Archangel: 'Arkhangelsk', Bugrino: 'Pechora', Cherepovets: 'Vologda',
};
