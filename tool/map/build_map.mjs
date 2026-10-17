// Map pipeline: Natural Earth admin-1 -> ~300 game provinces.
//
//   node build_map.mjs [--fresh] [--simplify=<percent>]
//
// Stage 1 (mapshaper): clip to the game window, delete tiny islands, project.
// Stage 2 (here):      assign 1914 owners, merge small units into provinces.
// Stage 3 (mapshaper): dissolve by province, simplify, clean.
// Stage 4 (here):      quantize, adjacency, sea links, income, write assets.
//
// Outputs assets/map/europe.json, one assets/scenarios/<id>.json per scenario
// and assets/scenarios/index.json listing them, plus preview PNGs and province
// lists under tool/map/out/ for eyeballing the result. The 1914 config shapes
// the map; every other scenario only assigns its provinces.
import mapshaper from 'mapshaper';
import polylabel from 'polylabel';
import { Resvg } from '@resvg/resvg-js';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as cfg from './config/scenario_1914.mjs';
import * as modernCfg from './config/scenario_modern.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const raw = (p) => path.join(here, 'raw', p);
const out = (p) => path.join(here, 'out', p);
mkdirSync(out(''), { recursive: true });
mkdirSync(path.join(root, 'assets/map'), { recursive: true });
mkdirSync(path.join(root, 'assets/scenarios'), { recursive: true });

const args = process.argv.slice(2);
const fresh = args.includes('--fresh');
const simplifyPct = Number((args.find((a) => a.startsWith('--simplify=')) ?? '--simplify=26').split('=')[1]);

/** Map units: the window is MAP_W wide; coordinates are stored as ints * SCALE. */
const MAP_W = 2048;
const SCALE = 4;

// ---------------------------------------------------------------- projection
const R = 6378137;
const mercX = (lon) => (R * lon * Math.PI) / 180;
const mercY = (lat) => R * Math.log(Math.tan(Math.PI / 4 + (lat * Math.PI) / 360));
const mercLat = (y) => ((2 * Math.atan(Math.exp(y / R)) - Math.PI / 2) * 180) / Math.PI;
const X0 = mercX(cfg.BBOX.w);
const X1 = mercX(cfg.BBOX.e);
const Y0 = mercY(cfg.BBOX.s);
const Y1 = mercY(cfg.BBOX.n);
const UNIT = (X1 - X0) / MAP_W; // metres of Mercator per map unit
const MAP_H = Math.round((Y1 - Y0) / UNIT);
const toMap = ([x, y]) => [(x - X0) / UNIT, (Y1 - y) / UNIT];
const lonLatToMap = ([lon, lat]) => toMap([mercX(lon), mercY(lat)]);

// ---------------------------------------------------------------- topology helpers
const ringsOf = (g) => (g.type === 'Polygon' ? g.arcs : g.type === 'MultiPolygon' ? g.arcs.flat() : []);
const polygonsOf = (g) => (g.type === 'Polygon' ? [g.arcs] : g.type === 'MultiPolygon' ? g.arcs : []);
const arcId = (ref) => (ref < 0 ? ~ref : ref);
const onlyLayer = (topology) => topology.objects[Object.keys(topology.objects)[0]];

function arcUsers(geoms) {
  const users = new Map();
  geoms.forEach((g, gi) => {
    for (const ring of ringsOf(g)) {
      for (const ref of ring) {
        const id = arcId(ref);
        if (!users.has(id)) users.set(id, new Set());
        users.get(id).add(gi);
      }
    }
  });
  return users;
}

function ringCoords(arcs, ring) {
  const pts = [];
  for (const ref of ring) {
    const arc = ref < 0 ? [...arcs[~ref]].reverse() : arcs[ref];
    for (let i = pts.length ? 1 : 0; i < arc.length; i++) pts.push(arc[i]);
  }
  return pts;
}

function ringArea(pts) {
  let a = 0;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) a += pts[j][0] * pts[i][1] - pts[i][0] * pts[j][1];
  return a / 2;
}

function pointInRings(rings, [x, y]) {
  let inside = false;
  for (const pts of rings) {
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const [xi, yi] = pts[i];
      const [xj, yj] = pts[j];
      if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
    }
  }
  return inside;
}

// ---------------------------------------------------------------- stage 1
const stage1Path = out('stage1.json');
if (fresh || !existsSync(stage1Path)) {
  const { w, s, e, n } = cfg.BBOX;
  console.log('stage 1: clip, drop islands, project');
  await mapshaper.runCommands(
    [
      `-i "${raw('admin1/ne_10m_admin_1_states_provinces.shp')}"`,
      `-filter "this.bounds[2] > ${w} && this.bounds[0] < ${e} && this.bounds[3] > ${s} && this.bounds[1] < ${n}"`,
      `-filter '${JSON.stringify(cfg.EXCLUDE_ADM0)}.indexOf(adm0_a3) < 0'`,
      `-clip bbox=${w},${s},${e},${n}`,
      ...cfg.ERASE_BOXES.map((b) => `-erase bbox=${b.join(',')}`),
      `-filter-islands min-area=${cfg.AREA.islandPart}km2 remove-empty`,
      `-each "area_km2 = this.area / 1e6"`,
      `-filter-fields adm1_code,iso_3166_2,name,name_en,admin,adm0_a3,region,area_km2`,
      `-proj webmercator`,
      `-o format=topojson no-quantization "${stage1Path}"`,
    ].join(' '),
  );
  await mapshaper.runCommands(
    [
      `-i "${raw('places/ne_10m_populated_places_simple.shp')}"`,
      `-filter "longitude > ${w} && longitude < ${e} && latitude > ${s} && latitude < ${n}"`,
      `-filter-fields name,pop_max,adm0_a3,latitude,longitude,featurecla`,
      `-o format=json "${out('places.json')}"`,
    ].join(' '),
  );
}

// ---------------------------------------------------------------- stage 2
console.log('stage 2: owners and merging');
const topo1 = JSON.parse(readFileSync(stage1Path, 'utf8'));
const layer1 = onlyLayer(topo1);
const geoms1 = layer1.geometries.filter((g) => g.type);
const arcLen = topo1.arcs.map((arc) => {
  let len = 0;
  for (let i = 1; i < arc.length; i++) len += Math.hypot(arc[i][0] - arc[i - 1][0], arc[i][1] - arc[i - 1][1]);
  return len;
});

/** One cluster per raw unit to begin with; merging folds them together. */
const clusters = new Map();
const unclassified = new Map();
geoms1.forEach((g, gi) => {
  const p = g.properties;
  const cls = cfg.classify(p);
  if (!cls) {
    unclassified.set(p.adm0_a3, (unclassified.get(p.adm0_a3) ?? 0) + 1);
    return;
  }
  const samples = [];
  for (const ring of ringsOf(g)) {
    for (const ref of ring) {
      const arc = topo1.arcs[arcId(ref)];
      for (let i = 0; i < arc.length; i += 3) samples.push(arc[i]);
    }
  }
  clusters.set(gi, {
    id: gi,
    owner: cls.owner,
    group: cls.group,
    key: `${cls.owner}|${cls.group}`,
    members: [gi],
    area: p.area_km2,
    nb: new Map(),
    samples,
  });
});
if (unclassified.size) console.warn('  dropped, no 1914 owner:', Object.fromEntries(unclassified));

for (const [id, users] of arcUsers(geoms1)) {
  const list = [...users].filter((gi) => clusters.has(gi));
  if (list.length !== 2) continue;
  const [a, b] = list;
  clusters.get(a).nb.set(b, (clusters.get(a).nb.get(b) ?? 0) + arcLen[id]);
  clusters.get(b).nb.set(a, (clusters.get(b).nb.get(a) ?? 0) + arcLen[id]);
}

const largestMember = (c) => c.members.reduce((best, gi) => (geoms1[gi].properties.area_km2 > geoms1[best].properties.area_km2 ? gi : best));
const regionOf = (c) => geoms1[largestMember(c)].properties.region || '';

function merge(into, from) {
  into.members.push(...from.members);
  into.area += from.area;
  into.samples.push(...from.samples);
  into.nb.delete(from.id);
  for (const [n, len] of from.nb) {
    if (n === into.id) continue;
    const other = clusters.get(n);
    other.nb.delete(from.id);
    other.nb.set(into.id, (other.nb.get(into.id) ?? 0) + len);
    into.nb.set(n, (into.nb.get(n) ?? 0) + len);
  }
  clusters.delete(from.id);
}

/** Best neighbor to fold `c` into: long shared border, small partner, same region. */
function bestNeighbor(c, sameKey) {
  let best = null;
  let bestScore = -1;
  const region = regionOf(c);
  for (const [n, len] of c.nb) {
    const other = clusters.get(n);
    if (sameKey && other.key !== c.key) continue;
    if (!sameKey && cfg.KEEP_GROUPS.includes(other.group)) continue;
    let score = len / Math.sqrt(other.area);
    if (sameKey && region && regionOf(other) === region) score *= 1.6;
    if (score > bestScore) {
      bestScore = score;
      best = other;
    }
  }
  return best;
}

const bySmallest = () => [...clusters.values()].sort((a, b) => a.area - b.area || a.id - b.id);

// (1) Units too small to be a province always merge inside their own group.
for (let changed = true; changed; ) {
  changed = false;
  for (const c of bySmallest()) {
    if (c.area >= cfg.AREA.forceMerge) break;
    const n = bestNeighbor(c, true);
    if (n) {
      merge(n, c);
      changed = true;
      break;
    }
  }
}

// (2) Lone enclaves (Monaco, San Marino, clip slivers) join their surroundings.
for (let changed = true; changed; ) {
  changed = false;
  for (const c of bySmallest()) {
    if (c.area >= cfg.AREA.absorb) break;
    if (cfg.KEEP_GROUPS.includes(c.group) || c.nb.size === 0) continue;
    const n = bestNeighbor(c, false);
    if (n) {
      merge(n, c);
      changed = true;
      break;
    }
  }
}

// (3) Lone small islands join the nearest province of their own group, or vanish.
const kmBetween = (a, b) => {
  let best = Infinity;
  for (const p of a.samples) {
    for (const q of b.samples) {
      const d = (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2;
      if (d < best) best = d;
    }
  }
  const lat = mercLat((a.samples[0][1] + b.samples[0][1]) / 2);
  return (Math.sqrt(best) * Math.cos((lat * Math.PI) / 180)) / 1000;
};
for (const c of bySmallest()) {
  if (c.nb.size > 0 || c.area >= cfg.AREA.islandAttach) continue;
  let near = null;
  let nearKm = cfg.AREA.islandAttachKm;
  for (const other of clusters.values()) {
    if (other === c || other.key !== c.key) continue;
    const km = kmBetween(c, other);
    if (km < nearKm) {
      nearKm = km;
      near = other;
    }
  }
  const name = geoms1[largestMember(c)].properties.name;
  if (near) {
    console.log(`  island ${name} (${Math.round(c.area)} km2) joins ${geoms1[largestMember(near)].properties.name}, ${Math.round(nearKm)} km`);
    merge(near, c);
  } else if (c.area < cfg.AREA.drop) {
    console.log(`  island ${name} (${Math.round(c.area)} km2) dropped`);
    clusters.delete(c.id);
  }
}

// (4) Merge down to the province count of each owner/group pair.
const groupArea = new Map();
const keyArea = new Map();
for (const c of clusters.values()) {
  groupArea.set(c.group, (groupArea.get(c.group) ?? 0) + c.area);
  keyArea.set(c.key, (keyArea.get(c.key) ?? 0) + c.area);
}
const keyTarget = new Map();
for (const [key, area] of keyArea) {
  const group = key.split('|')[1];
  let total = cfg.TARGETS[group];
  if (total === undefined) {
    total = Math.max(1, Math.round(groupArea.get(group) / 30000));
    console.warn(`  no target for group ${group}, using ${total}`);
  }
  keyTarget.set(key, Math.max(1, Math.round((total * area) / groupArea.get(group))));
}
for (const [key, target] of keyTarget) {
  for (;;) {
    const mine = bySmallest().filter((c) => c.key === key);
    if (mine.length <= target) break;
    let done = false;
    for (const c of mine) {
      const n = bestNeighbor(c, true);
      if (n) {
        merge(n, c);
        done = true;
        break;
      }
    }
    if (!done) break; // only disconnected pieces left
  }
}

// Fallback name (the largest unit); stage 4 prefers the biggest city.
const provinces1 = [...clusters.values()].sort((a, b) => a.key.localeCompare(b.key) || b.area - a.area);
for (const c of provinces1) c.name = geoms1[largestMember(c)].properties.name_en || geoms1[largestMember(c)].properties.name || '?';
provinces1.forEach((c, pid) => {
  for (const gi of c.members) geoms1[gi].properties = { pid, owner: c.owner, group: c.group, pname: c.name, area_km2: geoms1[gi].properties.area_km2 };
});
layer1.geometries = geoms1.filter((g) => g.properties.pid !== undefined);
writeFileSync(out('stage2.json'), JSON.stringify(topo1));
console.log(`  ${geoms1.length} raw units -> ${provinces1.length} provinces`);

// ---------------------------------------------------------------- stage 3
console.log(`stage 3: dissolve and simplify ${simplifyPct}%`);
await mapshaper.runCommands(
  [
    `-i "${out('stage2.json')}"`,
    `-dissolve pid copy-fields=owner,group,pname sum-fields=area_km2`,
    `-simplify weighted ${simplifyPct}% keep-shapes`,
    `-clean`,
    `-o format=topojson no-quantization "${out('final.json')}"`,
  ].join(' '),
);

// ---------------------------------------------------------------- stage 4
console.log('stage 4: assets');
const topo = JSON.parse(readFileSync(out('final.json'), 'utf8'));
const geoms = onlyLayer(topo)
  .geometries.filter((g) => g.type)
  .sort((a, b) => a.properties.pid - b.properties.pid);

// Quantize arcs to integer map coordinates, dropping repeated points.
const arcsF = topo.arcs.map((arc) => arc.map(toMap));
const arcsQ = arcsF.map((arc) => {
  const flat = [];
  for (const [x, y] of arc) {
    const qx = Math.round(x * SCALE);
    const qy = Math.round(y * SCALE);
    const n = flat.length;
    if (n >= 2 && flat[n - 2] === qx && flat[n - 1] === qy) continue;
    flat.push(qx, qy);
  }
  if (flat.length === 2) flat.push(flat[0], flat[1]);
  return flat;
});
const arcsMap = arcsQ.map((flat) => {
  const pts = [];
  for (let i = 0; i < flat.length; i += 2) pts.push([flat[i] / SCALE, flat[i + 1] / SCALE]);
  return pts;
});

const nationIndex = new Map(cfg.NATIONS.map((n, i) => [n.tag, i]));
const provinces = geoms.map((g, id) => {
  const polys = polygonsOf(g).map((poly) => poly.map((ring) => ringCoords(arcsMap, ring)));
  const biggest = polys.reduce((best, poly) => (Math.abs(ringArea(poly[0])) > Math.abs(ringArea(best[0])) ? poly : best));
  const label = polylabel(biggest, 0.5);
  const rings = polys.flat();
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const ring of rings) {
    for (const [x, y] of ring) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (!nationIndex.has(g.properties.owner)) throw new Error(`unknown owner ${g.properties.owner}`);
  return {
    id,
    name: g.properties.pname,
    modern: g.properties.group,
    owner: g.properties.owner,
    area: Math.round(g.properties.area_km2),
    ringRefs: ringsOf(g),
    rings,
    bounds: [minX, minY, maxX, maxY],
    label: [label[0], label[1]],
    radius: label.distance,
    adj: new Set(),
    sea: new Set(),
    pop: 0,
    city: null,
    cityPop: 0,
  };
});

for (const users of arcUsers(geoms).values()) {
  const list = [...users];
  for (const a of list) for (const b of list) if (a !== b) provinces[a].adj.add(b);
}

function provinceAt(pt) {
  for (const p of provinces) {
    const [minX, minY, maxX, maxY] = p.bounds;
    if (pt[0] < minX || pt[0] > maxX || pt[1] < minY || pt[1] > maxY) continue;
    if (pointInRings(p.rings, pt)) return p;
  }
  return null;
}
function nearestProvince(pt, maxDist) {
  let best = null;
  let bestD = maxDist * maxDist;
  for (const p of provinces) {
    const [minX, minY, maxX, maxY] = p.bounds;
    if (pt[0] < minX - maxDist || pt[0] > maxX + maxDist || pt[1] < minY - maxDist || pt[1] > maxY + maxDist) continue;
    for (const ring of p.rings) {
      for (const [x, y] of ring) {
        const d = (x - pt[0]) ** 2 + (y - pt[1]) ** 2;
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
    }
  }
  return best;
}
const locate = (lonLat, what, slack = 6) => {
  const pt = lonLatToMap(lonLat);
  const hit = provinceAt(pt);
  if (hit) return hit;
  const near = nearestProvince(pt, slack);
  if (!near) throw new Error(`${what}: ${lonLat} is not inside or near any province`);
  return near;
};

// Income from the people living there (modern figures stand in for 1914).
const places = JSON.parse(readFileSync(out('places.json'), 'utf8'));
let placed = 0;
for (const pl of places) {
  const pt = lonLatToMap([pl.longitude, pl.latitude]);
  const p = provinceAt(pt) ?? nearestProvince(pt, 5);
  if (!p) continue;
  placed++;
  p.pop += pl.pop_max;
  if (pl.pop_max > p.cityPop) {
    p.cityPop = pl.pop_max;
    p.city = pl.name;
  }
}
console.log(`  ${placed}/${places.length} cities placed`);

/** Income from the people living there, scaled by how developed it is. */
const incomeFor = (p, development) => Math.max(1, Math.round((1.5 + Math.sqrt(p.pop / 100000)) * development));

// 1914 income: modern population, scaled by how developed the region was.
for (const p of provinces) p.income = incomeFor(p, cfg.DEVELOPMENT[p.modern] ?? 1);

/**
 * Names the provinces after their biggest city, through [rename]; when two
 * would share a name, the second takes its admin-1 name instead.
 */
function pickNames(rename) {
  const used = new Set();
  return provinces.map((p) => {
    let name = rename[p.baseName] ?? p.baseName;
    if (used.has(name)) name = rename[p.adminName] ?? p.adminName;
    if (used.has(name)) throw new Error(`duplicate province name ${name}`);
    used.add(name);
    return name;
  });
}

// Names: the biggest city, as it was called in 1914.
for (const p of provinces) {
  p.baseName = (p.city ?? p.name).replace(/\p{Cf}/gu, '').replace(/\s+/g, ' ').trim();
  p.adminName = p.name;
}
pickNames(cfg.RENAME).forEach((name, i) => (provinces[i].name = name));

// Sea links, then make sure nothing is cut off.
for (const [a, b, label] of cfg.SEA_LINKS) {
  const pa = locate(a, label);
  const pb = locate(b, label);
  if (pa === pb) throw new Error(`sea link ${label}: both ends in ${pa.name}`);
  if (pa.adj.has(pb.id)) {
    console.warn(`  sea link ${label}: ${pa.name} and ${pb.name} already share a border`);
    continue;
  }
  pa.sea.add(pb.id);
  pb.sea.add(pa.id);
}
const component = () => {
  const comp = new Array(provinces.length).fill(-1);
  let count = 0;
  for (const start of provinces) {
    if (comp[start.id] >= 0) continue;
    const queue = [start.id];
    comp[start.id] = count;
    while (queue.length) {
      const p = provinces[queue.pop()];
      for (const n of [...p.adj, ...p.sea]) {
        if (comp[n] < 0) {
          comp[n] = count;
          queue.push(n);
        }
      }
    }
    count++;
  }
  return { comp, count };
};
for (;;) {
  const { comp, count } = component();
  if (count === 1) break;
  const sizes = new Array(count).fill(0);
  comp.forEach((c) => sizes[c]++);
  const small = sizes.indexOf(Math.min(...sizes));
  let best = null;
  let bestD = Infinity;
  for (const a of provinces.filter((p) => comp[p.id] === small)) {
    for (const b of provinces.filter((p) => comp[p.id] !== small)) {
      for (const ra of a.rings) for (const pa of ra) for (const rb of b.rings) for (let i = 0; i < rb.length; i += 2) {
        const d = (pa[0] - rb[i][0]) ** 2 + (pa[1] - rb[i][1]) ** 2;
        if (d < bestD) {
          bestD = d;
          best = [a, b];
        }
      }
    }
  }
  console.warn(`  AUTO sea link ${best[0].name} - ${best[1].name} (add it to SEA_LINKS if it should stay)`);
  best[0].sea.add(best[1].id);
  best[1].sea.add(best[0].id);
}

const mapJson = {
  version: 1,
  name: 'europe',
  width: MAP_W,
  height: MAP_H,
  scale: SCALE,
  bbox: [cfg.BBOX.w, cfg.BBOX.s, cfg.BBOX.e, cfg.BBOX.n],
  arcs: arcsQ,
  provinces: provinces.map((p) => ({
    id: p.id,
    name: p.name,
    modern: p.modern,
    area: p.area,
    pop: p.pop,
    label: [Math.round(p.label[0] * SCALE), Math.round(p.label[1] * SCALE)],
    radius: Math.round(p.radius * SCALE),
    rings: p.ringRefs,
    adj: [...p.adj].sort((a, b) => a - b),
    sea: [...p.sea].sort((a, b) => a - b),
  })),
};
mapJson.build = createHash('sha1').update(JSON.stringify(mapJson)).digest('hex').slice(0, 10);
// Sea zones come after the build id: they never move a province, so saves
// made before them stay good.
Object.assign(mapJson, seaZones());
const mapText = JSON.stringify(mapJson);
writeFileSync(path.join(root, 'assets/map/europe.json'), mapText);

// ---------------------------------------------------------------- sea zones
/**
 * The sea zones of the config and, for every province, the zones its coast
 * touches: each stretch of coast goes to the zone of the nearest sea point
 * within SEA_REACH_KM. Coast is an arc on a province's outer ring that no
 * other province shares and that does not run along the edge of the window;
 * shores of lakes lie on inner rings and are left out.
 */
function seaZones() {
  const zones = cfg.SEAS;
  const zoneIndex = new Map(zones.map((z, i) => [z.name, i]));
  const toLonLat = ([x, y]) => [cfg.BBOX.w + (x / MAP_W) * (cfg.BBOX.e - cfg.BBOX.w), mercLat(Y1 - y * UNIT)];
  const km = ([lon1, lat1], [lon2, lat2]) => {
    const rad = Math.PI / 180;
    const a = Math.sin(((lat2 - lat1) * rad) / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(((lon2 - lon1) * rad) / 2) ** 2;
    return 2 * 6371 * Math.asin(Math.sqrt(a));
  };
  const onEdge = ([x, y]) => x < 0.5 || y < 0.5 || x > MAP_W - 0.5 || y > MAP_H - 0.5;
  const users = arcUsers(geoms);
  const coast = provinces.map(() => new Set());
  const unplaced = new Set();
  geoms.forEach((g, id) => {
    for (const polygon of polygonsOf(g)) {
      for (const ref of polygon[0]) {
        const arc = arcsMap[arcId(ref)];
        if (users.get(arcId(ref)).size !== 1 || arc.every(onEdge)) continue;
        // Sample the arc every few points: a long coast may face two seas.
        const step = Math.max(1, Math.floor(arc.length / 12));
        for (let i = 0; i < arc.length; i += step) {
          if (onEdge(arc[i])) continue;
          const at = toLonLat(arc[i]);
          let best = -1;
          let bestKm = cfg.SEA_REACH_KM;
          zones.forEach((z, zi) => {
            for (const point of z.points) {
              const d = km(at, point);
              if (d < bestKm) {
                bestKm = d;
                best = zi;
              }
            }
          });
          if (best >= 0) coast[id].add(best);
          else unplaced.add(provinces[id].name);
        }
      }
    }
  });
  if (unplaced.size) console.warn(`  coast with no sea zone in reach: ${[...unplaced].join(', ')}`);
  for (const z of zones) {
    for (const other of z.links) {
      if (!zoneIndex.has(other)) throw new Error(`sea ${z.name}: no sea called ${other}`);
      if (!zones[zoneIndex.get(other)].links.includes(z.name)) throw new Error(`sea ${z.name} links to ${other}, but not back`);
    }
  }
  const seaLines = zones.map((z, zi) => `${z.name}: ${provinces.filter((p) => coast[p.id].has(zi)).map((p) => p.name).join(', ')}`);
  writeFileSync(out('seas.txt'), seaLines.join('\n'));
  return {
    seas: zones.map((z) => {
      const [x, y] = lonLatToMap(z.label);
      return { name: z.name, label: [Math.round(x * SCALE), Math.round(y * SCALE)], adj: z.links.map((l) => zoneIndex.get(l)).sort((a, b) => a - b) };
    }),
    coast: coast.map((set) => [...set].sort((a, b) => a - b)),
  };
}

// ---------------------------------------------------------------- scenarios
/**
 * Writes scenario [sc] on the finished provinces. [ownerOf] gives a
 * province's owner tag, [developmentOf] its development factor, and [names]
 * the province names when they differ from the map's (1914) ones. Returns
 * the province list for the report and the capitals.
 */
function writeScenario(sc, { ownerOf, developmentOf, names = null }) {
  const id = sc.SCENARIO_META.id;
  const index = new Map(sc.NATIONS.map((n, i) => [n.tag, i]));
  const nation = (tag, what) => {
    if (!index.has(tag)) throw new Error(`${id}: ${what} names unknown nation ${tag}`);
    return index.get(tag);
  };
  const nameOf = (p) => names?.[p.id] ?? p.name;
  const owners = provinces.map((p) => nation(ownerOf(p), `the owner of ${p.name}`));
  const income = provinces.map((p) => incomeFor(p, developmentOf(p)));
  const capitals = sc.NATIONS.map((n) => {
    const p = locate(n.capital, `${id}: capital of ${n.tag}`, 40);
    if (ownerOf(p) !== n.tag) throw new Error(`${id}: capital of ${n.tag} lands in ${nameOf(p)}, owned by ${ownerOf(p)}`);
    return p.id;
  });
  const forts = sc.FORTS ?? {};
  for (const name of Object.keys(forts)) {
    if (!provinces.some((p) => nameOf(p) === name)) throw new Error(`${id}: fort in ${name}: no such province`);
  }
  const pairs = (list, what) => (list ?? []).map(([a, b]) => [nation(a, what), nation(b, what)]);
  const json = {
    version: 1,
    ...sc.SCENARIO_META,
    map: 'europe',
    mapBuild: mapJson.build,
    nations: sc.NATIONS.map((n, i) => ({
      tag: n.tag,
      name: n.name,
      short: n.short,
      color: n.color,
      capital: capitals[i],
      readiness: n.ready ?? sc.DEFAULT_READY ?? 1,
      tech: n.tech ?? sc.DEFAULT_TECH ?? [0, 0],
      flag: n.flag ?? '',
    })),
    owners,
    income,
    ...(names ? { names } : {}),
    wars: pairs(sc.WARS, 'a war'),
    alliances: pairs(sc.ALLIANCES, 'an alliance'),
    forts: provinces.map((p) => forts[nameOf(p)] ?? 0),
    history: historyJson(sc, index),
  };
  writeFileSync(path.join(root, `assets/scenarios/${id}.json`), JSON.stringify(json));

  const lines = [];
  for (const n of sc.NATIONS) {
    const mine = provinces.filter((p) => ownerOf(p) === n.tag);
    if (mine.length === 0) throw new Error(`${id}: ${n.tag} holds no province`);
    lines.push(`${n.tag} ${n.name}: ${mine.length} provinces, income ${mine.reduce((s, p) => s + income[p.id], 0)}, capital ${nameOf(provinces[capitals[index.get(n.tag)]])}`);
    for (const p of mine) {
      const sea = p.sea.size ? `, sea ${[...p.sea].map((s) => nameOf(provinces[s])).join('/')}` : '';
      lines.push(`   #${p.id} ${nameOf(p)} [${p.modern}] ${p.area} km2, income ${income[p.id]}, city ${p.city ?? '-'}, adj ${p.adj.size}${sea}`);
    }
  }
  return { lines, capitals };
}

/** Scripted events, with dates turned into turns and tags into nation ids. */
function historyJson(sc, index) {
  const id = (tag) => {
    if (!index.has(tag)) throw new Error(`history: unknown nation ${tag}`);
    return index.get(tag);
  };
  return (sc.HISTORY ?? []).map((h) => {
    const turn = (h.date[0] - sc.SCENARIO_META.startYear) * 12 + h.date[1] - sc.SCENARIO_META.startMonth;
    if (turn < 1) throw new Error(`history: ${h.text} falls before the scenario opens`);
    return {
      turn,
      text: h.text,
      alliances: (h.alliances ?? []).map(([a, b]) => [id(a), id(b)]),
      wars: (h.wars ?? []).map(([a, b]) => [id(a), id(b)]),
    };
  });
}

// The Great War: owners, names and income as the map was built for them.
const great = writeScenario(cfg, { ownerOf: (p) => p.owner, developmentOf: (p) => cfg.DEVELOPMENT[p.modern] ?? 1 });
const capitals = great.capitals;

// Europe today: owners from each province's modern country (bar a few set by
// 1914 province name), names from the largest city in today's spelling,
// income from today's development. Forts take today's names.
for (const name of Object.keys(modernCfg.OWNER_BY_PROVINCE)) {
  if (!provinces.some((p) => p.name === name)) throw new Error(`modern owner for ${name}: no such province`);
}
const modernOwner = (p) => modernCfg.OWNER_BY_PROVINCE[p.name] ?? p.modern;
const modern = writeScenario(modernCfg, {
  ownerOf: modernOwner,
  developmentOf: (p) => modernCfg.DEVELOPMENT[modernOwner(p)] ?? 1,
  names: pickNames(modernCfg.RENAME),
});

writeFileSync(path.join(root, 'assets/scenarios/index.json'), JSON.stringify([cfg.SCENARIO_META.id, modernCfg.SCENARIO_META.id]));

// ---------------------------------------------------------------- report
const points = arcsQ.reduce((s, a) => s + a.length / 2, 0);
console.log(`  ${provinces.length} provinces, ${arcsQ.length} arcs, ${points} points, map ${MAP_W}x${MAP_H}, ${(mapText.length / 1024).toFixed(0)} KB, build ${mapJson.build}`);
writeFileSync(out('provinces.txt'), great.lines.join('\n'));
writeFileSync(out('provinces_modern.txt'), modern.lines.join('\n'));
console.log(great.lines.filter((l) => !l.startsWith(' ')).join('\n'));

// ---------------------------------------------------------------- previews
const color = new Map(cfg.NATIONS.map((n) => [n.tag, n.color]));
function preview(file, [vx, vy, vw, vh], px, withNames) {
  const parts = [`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vx} ${vy} ${vw} ${vh}"><rect x="${vx}" y="${vy}" width="${vw}" height="${vh}" fill="#9db7c4"/>`];
  const sw = vw / px;
  for (const p of provinces) {
    const d = p.rings.map((ring) => `M${ring.map(([x, y]) => `${x.toFixed(2)} ${y.toFixed(2)}`).join('L')}Z`).join('');
    parts.push(`<path d="${d}" fill="${color.get(p.owner)}" fill-rule="evenodd" stroke="#2b2b2b" stroke-width="${sw * 0.8}"/>`);
  }
  for (const p of provinces) {
    for (const s of p.sea) {
      if (s < p.id) continue;
      const q = provinces[s];
      parts.push(`<line x1="${p.label[0]}" y1="${p.label[1]}" x2="${q.label[0]}" y2="${q.label[1]}" stroke="#fff" stroke-width="${sw * 1.5}" stroke-dasharray="${sw * 5} ${sw * 4}"/>`);
    }
  }
  capitals.forEach((id) => {
    const p = provinces[id];
    parts.push(`<circle cx="${p.label[0]}" cy="${p.label[1]}" r="${sw * 5}" fill="#fff" stroke="#000" stroke-width="${sw}"/>`);
  });
  if (withNames) {
    for (const p of provinces) {
      parts.push(`<text x="${p.label[0]}" y="${p.label[1]}" font-size="${sw * 11}" font-family="Arial" text-anchor="middle" fill="#000" stroke="#fff" stroke-width="${sw * 2.5}" paint-order="stroke">${p.name.replace(/&/g, '&amp;')} ${p.income}</text>`);
    }
  }
  parts.push('</svg>');
  const png = new Resvg(parts.join(''), { fitTo: { mode: 'width', value: px }, font: { loadSystemFonts: true } }).render().asPng();
  writeFileSync(out(file), png);
}
preview('preview_full.png', [0, 0, MAP_W, MAP_H], 1500, false);
preview('preview_west.png', [0, MAP_H * 0.42, MAP_W * 0.5, MAP_H * 0.5], 1700, true);
preview('preview_central.png', [MAP_W * 0.3, MAP_H * 0.4, MAP_W * 0.45, MAP_H * 0.42], 1700, true);
preview('preview_east.png', [MAP_W * 0.5, MAP_H * 0.05, MAP_W * 0.5, MAP_H * 0.5], 1700, true);
preview('preview_south.png', [MAP_W * 0.45, MAP_H * 0.6, MAP_W * 0.55, MAP_H * 0.4], 1700, true);
preview('preview_north.png', [MAP_W * 0.15, 0, MAP_W * 0.5, MAP_H * 0.45], 1700, true);
console.log('done');
