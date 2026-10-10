// Dumps raw Natural Earth admin-1 attributes inside the game bbox, grouped by
// country. Used while authoring config/owners_1914.mjs.
//   node inspect_raw.mjs [ADM0_A3 ...]
import mapshaper from 'mapshaper';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const shp = path.join(here, 'raw/admin1/ne_10m_admin_1_states_provinces.shp');
const out = path.join(here, 'out/raw_attrs.json');

await mapshaper.runCommands(
  `-i "${shp}" -filter "this.bounds[2] > -12 && this.bounds[0] < 62 && this.bounds[3] > 27 && this.bounds[1] < 72" ` +
    `-each "area_km2 = Math.round(this.area / 1e6)" ` +
    `-filter-fields adm1_code,iso_3166_2,name,name_en,admin,adm0_a3,region,type_en,latitude,longitude,area_km2 ` +
    `-o format=json "${out}"`,
);

const rows = JSON.parse(readFileSync(out, 'utf8'));
const want = new Set(process.argv.slice(2));
const byCountry = new Map();
for (const r of rows) {
  if (!byCountry.has(r.adm0_a3)) byCountry.set(r.adm0_a3, []);
  byCountry.get(r.adm0_a3).push(r);
}
const keys = [...byCountry.keys()].sort();
for (const k of keys) {
  const list = byCountry.get(k);
  const area = list.reduce((s, r) => s + r.area_km2, 0);
  const regions = new Set(list.map((r) => r.region).filter(Boolean));
  console.log(`${k} ${list[0].admin}: ${list.length} units, ${area} km2, ${regions.size} regions`);
  if (want.has(k)) {
    for (const r of list.sort((a, b) => (a.region || '').localeCompare(b.region || '') || a.name?.localeCompare(b.name))) {
      console.log(`   ${r.iso_3166_2 || r.adm1_code} | ${r.name} | ${r.name_en ?? ''} | region=${r.region ?? ''} | ${r.type_en ?? ''} | ${r.area_km2} | ${r.longitude?.toFixed(1)},${r.latitude?.toFixed(1)}`);
    }
  }
}
console.log(`total ${rows.length} units in ${keys.length} countries`);
