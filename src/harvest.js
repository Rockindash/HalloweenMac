// The app's own artwork, ported line for line from the Swift drawing code in
// FallDock/Art/Art.swift and FallDock/Art/CozyArt.swift: the same shapes, palette and sizes,
// drawn on a canvas with the same bottom-left origin and turned into images.

// ---------- Palette ----------

const HEX = {
  dark: { green: 0x627329, rust: 0xa24b22, mustard: 0xdb9d24, orange: 0xeb6c15, plum: 0x5d1c2b, peach: 0xfcdcbe, stemCut: 0xc9773d, shadowInk: 0x3b1420, seed: 0xf6e4c1 },
  light: { green: 0x7c9440, rust: 0xbf6438, mustard: 0xedb54c, orange: 0xf58a3a, plum: 0x8a4452, peach: 0xfff2e3, stemCut: 0xde9a5e, shadowInk: 0x7a5446, seed: 0xfff7e8 },
};
const toRGB = v => [(v >> 16) & 255, (v >> 8) & 255, v & 255];
const PALETTES = Object.fromEntries(Object.entries(HEX).map(([k, o]) => [k, Object.fromEntries(Object.entries(o).map(([n, v]) => [n, toRGB(v)]))]));
export const palette = look => PALETTES[look] || PALETTES.dark;
export const mix = (a, b, t) => a.map((x, i) => x + (b[i] - x) * t);
export const css = (c, a = 1) => `rgba(${c.map(Math.round).join(',')},${a})`;

// ---------- Seeded randomness ----------

export function rng(seed) {
  let s = seed >>> 0 || 1;
  return {
    next() {
      s = (s + 0x6d2b79f5) | 0;
      let t = Math.imul(s ^ (s >>> 15), 1 | s);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    },
    float(a, b) {
      return a + (b - a) * this.next();
    },
  };
}

// ---------- Canvas helpers ----------

const P = (x, y) => ({ x, y });
const TAU = Math.PI * 2;

function poly(ctx, pts) {
  ctx.beginPath();
  pts.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
  ctx.closePath();
}
function fillPoly(ctx, pts, color) {
  poly(ctx, pts);
  ctx.fillStyle = color;
  ctx.fill();
}
function fillEllipse(ctx, x, y, w, h, color) {
  ctx.beginPath();
  ctx.ellipse(x + w / 2, y + h / 2, Math.abs(w / 2), Math.abs(h / 2), 0, 0, TAU);
  ctx.fillStyle = color;
  ctx.fill();
}
function fillRect(ctx, x, y, w, h, color) {
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w, h);
}
function roundRect(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

// ---------- Brush (tapered strokes) ----------

function bez(p, t) {
  const u = 1 - t;
  if (p.length === 3) return P(u * u * p[0].x + 2 * u * t * p[1].x + t * t * p[2].x, u * u * p[0].y + 2 * u * t * p[1].y + t * t * p[2].y);
  const a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
  return P(a * p[0].x + b * p[1].x + c * p[2].x + d * p[3].x, a * p[0].y + b * p[1].y + c * p[2].y + d * p[3].y);
}
function outline(points, width) {
  const n = points.length - 1;
  const left = [], right = [];
  for (let i = 0; i <= n; i++) {
    const a = points[Math.max(0, i - 1)], b = points[Math.min(n, i + 1)];
    const dx = b.x - a.x, dy = b.y - a.y, len = Math.max(0.0001, Math.hypot(dx, dy));
    const w = width(i / Math.max(1, n)) / 2;
    left.push(P(points[i].x - (dy / len) * w, points[i].y + (dx / len) * w));
    right.push(P(points[i].x + (dy / len) * w, points[i].y - (dx / len) * w));
  }
  return left.concat(right.reverse());
}
function stroke(ctx, controls, maxWidth, color, minF = 0.18, endF) {
  const end = endF ?? minF;
  const pts = [];
  for (let i = 0; i <= 22; i++) pts.push(bez(controls, i / 22));
  fillPoly(ctx, outline(pts, t => maxWidth * (t < 0.5 ? minF + (1 - minF) * Math.sin(Math.PI * t) : end + (1 - end) * Math.sin(Math.PI * t))), color);
}
function trail(ctx, points, maxWidth, color, minF = 0.15) {
  if (points.length < 2) return;
  fillPoly(ctx, outline(points, t => maxWidth * (minF + (1 - minF) * (1 - t))), color);
}
function tendril(ctx, start, dir, size, color) {
  const points = [];
  const end = P(start.x + dir * size * 0.25, start.y + size * 0.75);
  for (let i = 0; i <= 12; i++) {
    const t = i / 12;
    points.push(P(start.x + (end.x - start.x) * t + dir * Math.sin(Math.PI * t) * size * 0.12, start.y + (end.y - start.y) * t));
  }
  const radius = size * 0.26;
  const center = P(end.x + dir * radius, end.y);
  const steps = Math.floor(1.6 * 22);
  for (let i = 1; i <= steps; i++) {
    const phase = (i / 22) * TAU;
    const r = radius * (1 - (0.78 * i) / steps);
    points.push(P(center.x - dir * Math.cos(phase) * r, end.y + Math.sin(phase) * r));
  }
  trail(ctx, points, Math.max(1.4, size * 0.07), color, 0.3);
}

// ---------- Pumpkins ----------

export const PUMPKIN_KINDS = ['roundOrange', 'roundMustard', 'squatMustard', 'squatOrange', 'tallOrange', 'tallMustard', 'butternutOrange', 'butternutMustard', 'littleGreen'];
export const BALE_KINDS = ['roundOrange', 'roundMustard', 'squatOrange', 'squatMustard'];

const SHAPES = {
  roundOrange: ['round', 'orange', 1.34, 1],
  roundMustard: ['round', 'mustard', 1.26, 0.92],
  squatMustard: ['squat', 'mustard', 1.9, 0.66],
  squatOrange: ['squat', 'orange', 1.85, 0.68],
  tallOrange: ['tall', 'orange', 0.88, 0.95],
  tallMustard: ['tall', 'mustard', 0.87, 0.9],
  butternutOrange: ['butternut', 'orange', 0.6, 1.02],
  butternutMustard: ['butternut', 'mustard', 0.56, 1.05],
  littleGreen: ['squat', 'green', 1.7, 0.5],
};

export function pumpkinLook(kind, Pl) {
  const [shape, tone, aspect, heightFactor] = SHAPES[kind];
  const side = tone === 'orange' ? mix(Pl.orange, Pl.rust, 0.28) : tone === 'mustard' ? mix(Pl.mustard, Pl.rust, 0.25) : mix(Pl.green, Pl.plum, 0.25);
  return { shape, body: Pl[tone], side, rib: tone === 'green' ? Pl.plum : Pl.rust, aspect, heightFactor };
}

const PAD = 2;
function bodySize(kind, height) {
  const [shape, , aspect, hf] = SHAPES[kind];
  const h = (height * hf - PAD * 2) / (shape === 'butternut' ? 1.14 : 1.12);
  return { w: h * aspect, h };
}
export function pumpkinSize(kind, height) {
  const b = bodySize(kind, height);
  const h = b.h * (SHAPES[kind][0] === 'butternut' ? 1.14 : 1.12) + PAD * 2;
  return { w: Math.round(b.w * 1.08 + PAD * 2), h: Math.round(h) };
}

function lobes(shape) {
  if (shape === 'squat') return [[-0.27, 0.45, 0.24, 0.45, -6], [0.27, 0.45, 0.24, 0.45, 6], [0, 0.48, 0.3, 0.48, 0]];
  if (shape === 'tall') return [[-0.17, 0.47, 0.34, 0.47, -4], [0.17, 0.48, 0.34, 0.48, 4], [0, 0.47, 0.22, 0.47, 0]];
  return [[-0.2, 0.45, 0.31, 0.45, -8], [0.2, 0.46, 0.31, 0.46, 8], [0, 0.42, 0.26, 0.42, 0]];
}
function addLobe(ctx, l, cx, base, w, h, inset = 1) {
  const [a, b, rx, ry, rot] = l;
  ctx.save();
  ctx.translate(cx + a * w, base + b * h);
  ctx.rotate((-rot * Math.PI) / 180);
  ctx.moveTo(rx * w * inset, 0);
  ctx.ellipse(0, 0, rx * w * inset, ry * h * inset, 0, 0, TAU);
  ctx.restore();
}
function addButternut(ctx, cx, base, w, h) {
  const p = (x, y) => [cx + x * w, base + y * h];
  ctx.moveTo(...p(-0.5, 0.3));
  ctx.bezierCurveTo(...p(-0.52, -0.07), ...p(0.52, -0.07), ...p(0.5, 0.3));
  ctx.bezierCurveTo(...p(0.48, 0.55), ...p(0.28, 0.6), ...p(0.29, 0.88));
  ctx.quadraticCurveTo(...p(0, 1.02), ...p(-0.29, 0.88));
  ctx.bezierCurveTo(...p(-0.28, 0.6), ...p(-0.48, 0.55), ...p(-0.5, 0.3));
  ctx.closePath();
}
function bowRib(ctx, c, rx, ry, dir, a, b, t0, t1, width, color, sway = 0) {
  const pts = [];
  for (let i = 0; i <= 28; i++) {
    const t = (t0 + ((t1 - t0) * i) / 28) * Math.PI;
    pts.push(P(c.x + (dir * (a + b * Math.sin(t)) + sway * Math.sin(2 * t)) * rx, c.y + ry * Math.cos(t)));
  }
  fillPoly(ctx, outline(pts, u => width * (0.2 + 0.8 * Math.sin(Math.PI * Math.pow(u, 0.85)))), color);
}

function drawStem(ctx, Pl, base, length, angle, bw) {
  const a = (angle * Math.PI) / 180;
  const d = P(Math.sin(a), Math.cos(a));
  const n = P(Math.cos(a), -Math.sin(a));
  const tip = P(base.x + d.x * length, base.y + d.y * length);
  const tw = bw * 0.62, bend = bw * 0.35;
  const at = (along, across, o = base) => P(o.x + d.x * along + n.x * across, o.y + d.y * along + n.y * across);
  ctx.beginPath();
  let q = at(0, -bw / 2);
  ctx.moveTo(q.x, q.y);
  let c = at(length * 0.55, -(bw * 0.42 - bend));
  q = at(0, -tw / 2, tip);
  ctx.quadraticCurveTo(c.x, c.y, q.x, q.y);
  q = at(tw * 0.25, tw / 2, tip);
  ctx.lineTo(q.x, q.y);
  c = at(length * 0.55, bw * 0.42 + bend);
  q = at(0, bw / 2);
  ctx.quadraticCurveTo(c.x, c.y, q.x, q.y);
  ctx.closePath();
  ctx.fillStyle = css(Pl.rust);
  ctx.fill();

  const tw2 = bw * 0.7;
  stroke(ctx, [P(base.x + n.x * bw * 0.18, base.y + n.y * bw * 0.18 + 2), at(length * 0.5, bw * 0.16), P(tip.x + n.x * tw2 * 0.12, tip.y + n.y * tw2 * 0.12 - 2)], bw * 0.26, css(Pl.plum), 0.5, 0.3);

  const cut = P(tip.x + d.x * tw2 * 0.1, tip.y + d.y * tw2 * 0.1);
  ctx.save();
  ctx.translate(cut.x, cut.y);
  ctx.rotate(-a);
  ctx.beginPath();
  ctx.ellipse(0, 0, tw2 * 0.5, tw2 * 0.22, 0, 0, TAU);
  ctx.restore();
  ctx.fillStyle = css(Pl.stemCut);
  ctx.fill();
}

function drawPumpkin(ctx, Pl, kind, cx, base, w, h, variant) {
  const r = rng(variant * 7919 + PUMPKIN_KINDS.indexOf(kind) + 1);
  const look = pumpkinLook(kind, Pl);
  const lineW = Math.max(1.2, w * 0.028);
  const stemAngle = r.float(-12, 12);
  const rib = css(look.rib);

  if (look.shape === 'butternut') drawStem(ctx, Pl, P(cx, base + h * 0.85), h * 0.24, stemAngle, Math.max(4, w * 0.17));
  else drawStem(ctx, Pl, P(cx, base + h * 0.74), h * 0.3, stemAngle, Math.max(4, w * 0.14));

  if (look.shape === 'butternut') {
    const p = (x, y) => P(cx + x * w, base + y * h);
    ctx.beginPath();
    addButternut(ctx, cx, base, w, h);
    ctx.fillStyle = css(look.body);
    ctx.fill();

    // A darker right side on the bulb, kept inside the body.
    ctx.save();
    ctx.beginPath();
    addButternut(ctx, cx, base, w, h);
    ctx.clip();
    ctx.beginPath();
    let s = p(0.12, -0.02);
    ctx.moveTo(s.x, s.y);
    let c1 = p(0.42, 0.02), c2 = p(0.55, 0.25), e = p(0.44, 0.45);
    ctx.bezierCurveTo(c1.x, c1.y, c2.x, c2.y, e.x, e.y);
    c1 = p(0.38, 0.3); c2 = p(0.3, 0.1);
    ctx.bezierCurveTo(c1.x, c1.y, c2.x, c2.y, s.x, s.y);
    ctx.closePath();
    ctx.fillStyle = css(look.side);
    ctx.fill();
    ctx.restore();

    // Two S-curved ribs, clipped to a slightly smaller body.
    ctx.save();
    ctx.save();
    ctx.translate(cx, base + h * 0.45);
    ctx.scale(0.88, 0.88);
    ctx.translate(-cx, -(base + h * 0.45));
    ctx.beginPath();
    addButternut(ctx, cx, base, w, h);
    ctx.restore();
    ctx.clip();
    stroke(ctx, [p(-0.02, 0.86), p(0.04, 0.62), p(-0.56, 0.38), p(-0.2, 0.05)], lineW * 1.2, rib, 0.25, 0.2);
    stroke(ctx, [p(0.06, 0.8), p(-0.04, 0.55), p(0.48, 0.36), p(0.16, 0.05)], lineW * 1.2, rib, 0.25, 0.2);
    ctx.restore();

    fillEllipse(ctx, cx + w * 0.02 - w * 0.07, base + h * 0.06 - h * 0.025, w * 0.14, h * 0.05, css(Pl.rust, 0.6));
    return;
  }

  const [left, right, front] = lobes(look.shape);
  for (const [lobe, dir] of [[left, -1], [right, 1]]) {
    ctx.beginPath();
    addLobe(ctx, lobe, cx, base, w, h);
    ctx.fillStyle = css(look.side);
    ctx.fill();
    ctx.save();
    ctx.beginPath();
    addLobe(ctx, lobe, cx, base, w, h, 0.86);
    ctx.clip();
    bowRib(ctx, P(cx + lobe[0] * w, base + lobe[1] * h), lobe[2] * w, lobe[3] * h * 0.95, dir, 0.22, 0.34, 0.22, 0.78, lineW * 1.2, rib);
    ctx.restore();
  }

  ctx.beginPath();
  addLobe(ctx, front, cx, base, w, h);
  ctx.fillStyle = css(look.body);
  ctx.fill();
  ctx.save();
  ctx.beginPath();
  addLobe(ctx, front, cx, base, w, h, 0.88);
  ctx.clip();
  const fc = P(cx, base + front[1] * h), frx = front[2] * w, fry = front[3] * h * 0.95;
  bowRib(ctx, fc, frx, fry, -1, 0.24, 0.34, 0.2, 0.8, lineW * 1.2, rib);
  bowRib(ctx, fc, frx, fry, 1, 0.24, 0.34, 0.2, 0.8, lineW * 1.2, rib);
  if (frx > 12) bowRib(ctx, fc, frx, fry, 1, 0, 0, 0.24, 0.76, lineW * 1.05, rib, r.next() < 0.5 ? -0.07 : 0.07);
  ctx.restore();
}

// ---------- Leaves ----------

export const LEAF_KINDS = ['oak', 'ovate', 'serrated', 'plum'];
const leafFill = (kind, Pl) => ({ oak: Pl.mustard, ovate: Pl.rust, serrated: Pl.green, plum: Pl.plum })[kind];
const leafVein = (kind, Pl) => ({ oak: Pl.rust, ovate: Pl.plum, serrated: Pl.plum, plum: Pl.mustard })[kind];

function leafOutline(kind, length, width) {
  const top = [], bottom = [];
  const ovate = kind === 'ovate' || kind === 'plum';
  for (let i = 0; i <= 60; i++) {
    const t = i / 60;
    let hw = width * Math.pow(Math.sin(Math.PI * Math.pow(t, ovate ? 0.75 : 0.9)), 0.85);
    if (kind === 'oak') hw *= 0.78 + 0.32 * Math.abs(Math.sin(t * Math.PI * 4.5));
    if (kind === 'serrated') hw *= 1 - 0.16 * ((t * 9) % 1);
    top.push(P(t * length, hw));
    bottom.push(P(t * length, -hw * (ovate ? 1.05 : 1)));
  }
  return top.concat(bottom.reverse());
}

function drawWagonLeaf(ctx, Pl, kind, center, length, angle, flip) {
  const width = length * (kind === 'ovate' || kind === 'plum' ? 0.34 : 0.3);
  const vw = Math.max(0.7, length * 0.028);
  const vein = css(leafVein(kind, Pl));
  ctx.save();
  ctx.translate(center.x, center.y);
  ctx.rotate((angle * Math.PI) / 180);
  if (flip) ctx.scale(1, -1);
  ctx.translate(-length / 2, 0);
  stroke(ctx, [P(-length * 0.32, length * 0.06), P(-length * 0.15, length * 0.05), P(length * 0.05, 0)], vw * 1.1, vein, 0.6);
  fillPoly(ctx, leafOutline(kind, length, width), css(leafFill(kind, Pl)));
  stroke(ctx, [P(0, 0), P(length * 0.45, -length * 0.02), P(length * 0.88, 0)], vw * 1.3, vein, 0.5, 0.1);
  for (let k = 0; k < 5; k++) {
    const bx = (0.16 + k * 0.14) * length;
    const side = width * (0.6 - k * 0.08);
    for (const s of [1, -1]) stroke(ctx, [P(bx, 0), P(bx + length * 0.03, s * side * 0.6), P(bx + length * 0.12, s * side * 0.95)], vw, vein, 0.4, 0.1);
  }
  ctx.restore();
}

// ---------- Vine ----------

export const vineCenterY = (x, k) => 8 * k - (Math.sin(x / (47 * k)) * 3.2 + Math.sin(x / (17 * k)) * 1.2) * k;
export const vineBase = k => 8 * k;

function taperedVine(ctx, x0, x1, maxWidth, color, y) {
  if (x1 <= x0) return;
  const pts = [];
  for (let x = x0; x <= x1; x += 3) pts.push(P(x, y(x)));
  const width = t => {
    const x = x0 + (x1 - x0) * t;
    return maxWidth * (0.55 + 0.3 * Math.sin(x / 31) * Math.sin(x / 13) + 0.25 * Math.sin(Math.PI * t));
  };
  fillPoly(ctx, outline(pts, width), color);
  for (const [pt, t] of [[pts[0], 0], [pts[pts.length - 1], 1]]) {
    const rr = width(t) / 2;
    fillEllipse(ctx, pt.x - rr, pt.y - rr, rr * 2, rr * 2, color);
  }
}

function drawBud(ctx, Pl, start, length, angle) {
  const r = (angle * Math.PI) / 180;
  const tip = P(start.x + Math.cos(r) * length, start.y + Math.sin(r) * length);
  stroke(ctx, [start, P((start.x + tip.x) / 2 + 2, (start.y + tip.y) / 2), tip], 2.4, css(Pl.green), 0.6);
  ctx.save();
  ctx.translate(tip.x, tip.y);
  ctx.rotate(r - Math.PI / 2);
  fillEllipse(ctx, -length * 0.2, -length * 0.32, length * 0.4, length * 0.64, css(Pl.mustard));
  fillEllipse(ctx, -length * 0.1, -length * 0.3 + length * 0.05, length * 0.2, length * 0.6, css(Pl.orange));
  ctx.restore();
}

function drawVine(ctx, Pl, w, seed, k) {
  const r = rng(seed * 6151 + 3);
  const x0 = 4, x1 = w - 4;
  const vy = x => vineCenterY(x, k);
  const dark = mix(Pl.green, Pl.plum, 0.38);
  const width = 6 * k;

  let x = x0 + r.float(50, 90) * k;
  let i = 0;
  while (x < x1 - 30 * k) {
    const start = P(x, vy(x));
    const dir = i % 2 === 0 ? 1 : -1;
    const size = r.float(24, 42) * k;
    tendril(ctx, P(start.x + 1.2 * k, start.y - 1.2 * k), dir, size, css(dark));
    tendril(ctx, start, dir, size, css(Pl.green));
    x += r.float(75, 140) * k;
    i++;
  }

  taperedVine(ctx, x0, x1, width, css(Pl.green), vy);

  const ridges = rng(seed * 911 + 7);
  x = x0 + 3 * k;
  while (x < x1 - 3 * k) {
    if (ridges.next() < 0.65) {
      const y = vy(x);
      stroke(ctx, [P(x - 1.2 * k, y - width * 0.32), P(x, y - width * 0.05), P(x + 1.4 * k, y + width * 0.18)], Math.max(0.6, 0.75 * k), css(dark, 0.7), 0.3);
    }
    x += ridges.float(5, 9) * k;
  }

  x = x0 + r.float(200, 280) * k;
  while (x < x1 - 40 * k) {
    drawBud(ctx, Pl, P(x, vy(x)), r.float(14, 16) * k, r.float(70, 110));
    x += r.float(260, 340) * k;
  }
}

// ---------- Cozy extras ----------

const straw = Pl => mix(Pl.mustard, Pl.peach, 0.18);
const strawLight = Pl => mix(Pl.mustard, Pl.peach, 0.5);
const strawDark = Pl => mix(Pl.mustard, Pl.rust, 0.38);
const bark = Pl => mix(Pl.rust, Pl.plum, 0.55);
const wood = Pl => mix(Pl.rust, Pl.peach, 0.22);
const fur = Pl => mix(Pl.rust, Pl.orange, 0.3);

export const LATTE_STEAM = { x: 0.62, y: 0.86 };
export const LANTERN_FLAME = 0.36;

export function decorSize(kind, h) {
  const s = {
    hayBale: [1.4, 0.52],
    leafPile: [0.95, 0.42],
    acorns: [0.62, 0.4],
    mug: [0.46, 0.66],
    lantern: [0.46, 0.82],
    apples: [0.92, 0.58],
  }[kind];
  return { w: Math.round(h * s[0]), h: Math.round(h * s[1]) };
}

function drawHayBale(ctx, Pl, w, ht, h, r) {
  const front = { x: 1, y: 1, w: w - 2, h: ht * 0.78 };
  const top = { x: 4, y: ht * 0.6, w: w - 8, h: ht * 0.38 };
  const frontPath = () => {
    ctx.beginPath();
    roundRect(ctx, front.x, front.y, front.w, front.h, ht * 0.14);
  };
  ctx.beginPath();
  roundRect(ctx, top.x, top.y, top.w, top.h, ht * 0.12);
  ctx.fillStyle = css(strawLight(Pl));
  ctx.fill();
  frontPath();
  ctx.fillStyle = css(straw(Pl));
  ctx.fill();

  ctx.save();
  frontPath();
  ctx.clip();
  fillRect(ctx, w * 0.86, 0, w * 0.14, ht, css(mix(straw(Pl), Pl.rust, 0.2)));
  const lw = Math.max(0.8, h * 0.016);
  const n = Math.floor((w * ht) / 55);
  for (let i = 0; i < n; i++) {
    const x = r.float(front.x, front.x + front.w), y = r.float(front.y, front.y + front.h);
    const len = r.float(0.06, 0.14) * w;
    const tilt = r.float(-0.1, 0.1) * len;
    const color = r.next() < 0.7 ? strawDark(Pl) : strawLight(Pl);
    stroke(ctx, [P(x, y), P(x + len / 2, y + tilt), P(x + len, y + tilt * 0.4)], lw, css(color), 0.2);
  }
  ctx.restore();

  for (let i = 0; i < Math.floor(w / 6); i++) {
    const x = r.float(top.x + 4, top.x + top.w - 4), y = r.float(top.y + top.h * 0.45, top.y + top.h - 2);
    const len = (r.float(4, 9) * h) / 60;
    stroke(ctx, [P(x, y), P(x + len * 0.3, y + len * 0.5), P(x + len * 0.2, y + len)], lw, css(strawDark(Pl)), 0.3);
  }

  for (const fx of [0.27, 0.73]) {
    const x = w * fx;
    const fmax = front.y + front.h;
    stroke(ctx, [P(x, 2), P(x + 1, ht * 0.4), P(x, fmax - 1)], h * 0.035, css(Pl.rust), 0.8);
    stroke(ctx, [P(x, fmax - 1), P(x + 1.5, ht * 0.86), P(x + 1, top.y + top.h - 2)], h * 0.03, css(mix(Pl.rust, Pl.plum, 0.3)), 0.6, 0.4);
  }

  for (const [x, dir] of [[front.x + 2, -1], [front.x + front.w - 2, 1]]) {
    for (let i = 0; i < 4; i++) {
      const y = ht * (0.18 + i * 0.16);
      const len = (r.float(4, 7) * h) / 60;
      stroke(ctx, [P(x - dir * 2, y), P(x + dir * len * 0.6, y + len * 0.2), P(x + dir * len, y + r.float(-2, 3))], lw * 1.2, css(strawDark(Pl)), 0.5, 0.1);
    }
  }
}

function drawLeafPile(ctx, Pl, w, ht, h, r) {
  const kinds = ['oak', 'oak', 'ovate', 'ovate', 'plum', 'oak', 'serrated', 'ovate'];
  for (let row = 0; row < 4; row++) {
    const count = 5 - row;
    const rowY = ht * (0.18 + row * 0.17);
    const halfWidth = w * 0.42 * Math.sqrt(Math.max(0.05, 1 - Math.pow(row / 3.6, 2)));
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0.5 : i / (count - 1);
      const length = h * r.float(0.2, 0.27);
      const x = w / 2 - halfWidth + t * halfWidth * 2 + r.float(-3, 3);
      const y = rowY + r.float(-2, 2);
      const kind = kinds[Math.floor(r.float(0, 7.99))];
      drawWagonLeaf(ctx, Pl, kind, P(Math.min(w - length * 0.45, Math.max(length * 0.45, x)), y), length, r.float(0, 360), r.next() < 0.5);
    }
  }
}

function acorn(ctx, Pl, bottom, s, angle) {
  ctx.save();
  ctx.translate(bottom.x, bottom.y);
  ctx.rotate((angle * Math.PI) / 180);
  const nutW = s * 0.62, nutH = s * 0.72;
  const nut = () => {
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.bezierCurveTo(nutW * 0.26, 0, nutW / 2, nutH * 0.3, nutW / 2, nutH * 0.62);
    ctx.lineTo(-nutW / 2, nutH * 0.62);
    ctx.bezierCurveTo(-nutW / 2, nutH * 0.3, -nutW * 0.26, 0, 0, 0);
    ctx.closePath();
  };
  nut();
  ctx.fillStyle = css(mix(Pl.rust, Pl.mustard, 0.4));
  ctx.fill();
  ctx.save();
  nut();
  ctx.clip();
  fillEllipse(ctx, nutW * 0.12, -nutH * 0.1, nutW * 0.6, nutH * 0.9, css(mix(Pl.rust, Pl.mustard, 0.1)));
  ctx.restore();

  const cap = { x: -nutW * 0.6, y: nutH * 0.5, w: nutW * 1.2, h: s * 0.36 };
  fillEllipse(ctx, cap.x, cap.y, cap.w, cap.h, css(bark(Pl)));
  ctx.save();
  ctx.beginPath();
  ctx.ellipse(cap.x + cap.w / 2, cap.y + cap.h / 2, cap.w / 2, cap.h / 2, 0, 0, TAU);
  ctx.clip();
  const midY = cap.y + cap.h / 2;
  for (let i = 0; i < 4; i++) {
    const x = cap.x + cap.w * (0.2 + i * 0.2);
    stroke(ctx, [P(x - s * 0.06, midY - s * 0.06), P(x, midY + s * 0.02), P(x + s * 0.06, midY - s * 0.06)], Math.max(0.8, s * 0.05), css(Pl.plum), 0.4);
  }
  ctx.restore();
  const capTop = cap.y + cap.h;
  stroke(ctx, [P(0, capTop - s * 0.04), P(s * 0.03, capTop + s * 0.06), P(s * 0.09, capTop + s * 0.1)], s * 0.08, css(Pl.plum), 0.7);
  ctx.restore();
}

function drawAcorns(ctx, Pl, w, ht, h) {
  const s = h * 0.32;
  acorn(ctx, Pl, P(w * 0.3, 1), s, 6);
  acorn(ctx, Pl, P(w * 0.56, 1), s * 0.86, -8);
  acorn(ctx, Pl, P(w * 0.7, s * 0.27), s * 0.78, -78);
}

function drawMug(ctx, Pl, w, ht) {
  const p = (x, y) => P(x * w, y * ht);
  const cup = [p(0.24, 0.02), p(0.76, 0.02), p(0.88, 0.76), p(0.12, 0.76)];
  fillPoly(ctx, cup, css(Pl.peach));
  ctx.save();
  poly(ctx, cup);
  ctx.clip();
  fillRect(ctx, 0, ht * 0.2, w, ht * 0.32, css(mix(Pl.orange, Pl.rust, 0.35)));
  fillRect(ctx, w * 0.66, 0, w * 0.4, ht, css(Pl.shadowInk, 0.16));
  ctx.restore();

  const c = p(0.46, 0.36);
  const r = w * 0.1;
  const pc = css(mix(Pl.orange, Pl.mustard, 0.25));
  fillEllipse(ctx, c.x - r * 1.3, c.y - r * 0.85, r * 1.6, r * 1.7, pc);
  fillEllipse(ctx, c.x - r * 0.3, c.y - r * 0.85, r * 1.6, r * 1.7, pc);
  fillEllipse(ctx, c.x - r * 0.75, c.y - r * 0.9, r * 1.5, r * 1.8, css(mix(Pl.mustard, Pl.peach, 0.2)));
  stroke(ctx, [P(c.x, c.y + r * 0.8), P(c.x + r * 0.1, c.y + r * 1.1), P(c.x + r * 0.35, c.y + r * 1.3)], r * 0.4, css(Pl.green), 0.7);

  const lid = mix(Pl.plum, Pl.rust, 0.2);
  ctx.beginPath();
  roundRect(ctx, w * 0.06, ht * 0.74, w * 0.88, ht * 0.08, ht * 0.03);
  ctx.fillStyle = css(lid);
  ctx.fill();
  ctx.beginPath();
  roundRect(ctx, w * 0.16, ht * 0.8, w * 0.68, ht * 0.1, ht * 0.04);
  ctx.fillStyle = css(mix(lid, Pl.peach, 0.15));
  ctx.fill();
  fillEllipse(ctx, w * LATTE_STEAM.x - w * 0.07, ht * LATTE_STEAM.y - ht * 0.012, w * 0.14, ht * 0.03, css(Pl.shadowInk));
  const cin = css(mix(Pl.rust, Pl.plum, 0.4));
  for (const [x, y] of [[0.3, 0.5], [0.36, 0.47], [0.6, 0.49], [0.67, 0.46], [0.52, 0.23]]) fillEllipse(ctx, w * x, ht * y, w * 0.035, w * 0.035, cin);
}

function drawLantern(ctx, Pl, w, ht, h) {
  const metal = Pl.plum;
  const glass = { x: w * 0.2, y: ht * 0.1, w: w * 0.6, h: ht * 0.5 };
  fillRect(ctx, glass.x, glass.y, glass.w, glass.h, css(mix(Pl.mustard, Pl.peach, 0.35)));
  const dx = glass.w * 0.22, dy = glass.h * 0.12;
  fillRect(ctx, glass.x + dx, glass.y + dy, glass.w - dx * 2, glass.h - dy * 2, css(mix(Pl.peach, Pl.mustard, 0.15)));

  fillRect(ctx, w * 0.4, glass.y, w * 0.2, ht * 0.18, css(Pl.peach));
  const fy = ht * LANTERN_FLAME;
  ctx.beginPath();
  ctx.moveTo(w / 2, fy + ht * 0.14);
  ctx.bezierCurveTo(w / 2 + w * 0.1, fy + ht * 0.04, w / 2 + w * 0.09, fy - ht * 0.04, w / 2, fy - ht * 0.04);
  ctx.bezierCurveTo(w / 2 - w * 0.09, fy - ht * 0.04, w / 2 - w * 0.1, fy + ht * 0.04, w / 2, fy + ht * 0.14);
  ctx.fillStyle = css(Pl.orange);
  ctx.fill();
  fillEllipse(ctx, w / 2 - w * 0.04, fy - ht * 0.02, w * 0.08, ht * 0.08, css(Pl.mustard));

  fillRect(ctx, w * 0.12, 1, w * 0.76, ht * 0.1, css(metal));
  const gTop = glass.y + glass.h, gMid = glass.y + glass.h / 2;
  for (const x of [glass.x, glass.x + glass.w]) stroke(ctx, [P(x, glass.y), P(x, gMid), P(x, gTop)], h * 0.045, css(metal), 1);
  stroke(ctx, [P(w / 2, glass.y), P(w / 2, gMid), P(w / 2, gTop)], h * 0.018, css(metal, 0.6), 1);
  fillPoly(ctx, [P(w * 0.08, gTop), P(w * 0.92, gTop), P(w * 0.66, ht * 0.74), P(w * 0.34, ht * 0.74)], css(metal));
  fillRect(ctx, w * 0.6, gTop, w * 0.3, ht * 0.03, css(mix(metal, Pl.shadowInk, 0.4)));
  fillEllipse(ctx, w * 0.42, ht * 0.72, w * 0.16, ht * 0.07, css(metal));
  ctx.strokeStyle = css(metal);
  ctx.lineWidth = h * 0.03;
  ctx.beginPath();
  ctx.arc(w / 2, ht * 0.78, w * 0.2, 0.15, Math.PI - 0.15, false);
  ctx.stroke();
}

function apple(ctx, Pl, c, r, color, leaf) {
  fillEllipse(ctx, c.x - r, c.y - r, r * 2, r * 1.9, css(color));
  ctx.save();
  ctx.beginPath();
  ctx.ellipse(c.x, c.y - r + r * 0.95, r, r * 0.95, 0, 0, TAU);
  ctx.clip();
  fillEllipse(ctx, c.x + r * 0.2, c.y - r * 1.1, r * 1.4, r * 2.2, css(mix(color, Pl.plum, 0.3)));
  ctx.restore();
  fillEllipse(ctx, c.x - r * 0.55, c.y + r * 0.2, r * 0.32, r * 0.42, css(Pl.peach, 0.8));
  stroke(ctx, [P(c.x, c.y + r * 0.7), P(c.x + r * 0.05, c.y + r * 1.05), P(c.x + r * 0.2, c.y + r * 1.25)], r * 0.18, css(Pl.plum), 0.7);
  if (leaf) drawWagonLeaf(ctx, Pl, 'serrated', P(c.x + r * 0.6, c.y + r * 1.12), r * 1.2, 20, false);
}

function drawApples(ctx, Pl, w, ht, h, r) {
  const crate = { x: 1, y: 1, w: w - 2, h: ht * 0.52 };
  const rad = ht * 0.21;
  const colors = [mix(Pl.rust, Pl.orange, 0.2), Pl.rust, Pl.mustard, mix(Pl.rust, Pl.orange, 0.2)];
  for (let i = 0; i < 4; i++) {
    const cx = crate.x + crate.w * (0.16 + i * 0.225) + r.float(-2, 2);
    const cy = crate.y + crate.h + rad * (i % 2 === 0 ? 0.25 : 0.5);
    apple(ctx, Pl, P(cx, cy), rad, colors[i], i === 1);
  }
  const wd = wood(Pl);
  fillRect(ctx, crate.x, crate.y, crate.w, crate.h, css(wd));
  for (const f of [0.34, 0.67]) fillRect(ctx, crate.x, crate.y + crate.h * f - 1, crate.w, Math.max(1.5, ht * 0.035), css(mix(wd, Pl.plum, 0.4)));
  const post = css(mix(wd, Pl.plum, 0.25));
  fillRect(ctx, crate.x, crate.y, crate.w * 0.1, crate.h, post);
  fillRect(ctx, crate.x + crate.w * 0.9, crate.y, crate.w * 0.1, crate.h, post);
  for (let i = 0; i < 6; i++) {
    const x = r.float(crate.x + crate.w * 0.14, crate.x + crate.w * 0.7);
    const y = r.float(crate.y + 3, crate.y + crate.h - 3);
    const len = crate.w * r.float(0.12, 0.22);
    stroke(ctx, [P(x, y), P(x + len / 2, y + 0.6), P(x + len, y)], Math.max(0.8, h * 0.014), css(mix(wd, Pl.plum, 0.3)), 0.2);
  }
}

// ---------- Squirrel ----------

const squirrelBody = h => ({ w: h * 0.62, h: h * 0.56 });
const squirrelRoom = h => ({ w: h * 0.14, h: h * 0.1 });
export function squirrelSize(h) {
  const b = squirrelBody(h), r = squirrelRoom(h);
  return { w: Math.round(b.w + r.w), h: Math.round(b.h + r.h) };
}
export function tailBase(h) {
  const s = squirrelSize(h), b = squirrelBody(h), r = squirrelRoom(h);
  return { x: (r.w + b.w * 0.36) / s.w, y: (b.h * 0.22) / s.h };
}
export function squirrelPaws(h) {
  const s = squirrelSize(h), b = squirrelBody(h), r = squirrelRoom(h);
  return { x: r.w + b.w * 0.8 - s.w / 2, y: b.h * 0.42 };
}

function drawSquirrel(ctx, Pl, h) {
  const b = squirrelBody(h);
  ctx.translate(squirrelRoom(h).w, 0);
  const w = b.w, ht = b.h;
  const p = (x, y) => P(x * w, y * ht);
  const f = fur(Pl), furDark = mix(f, Pl.plum, 0.3);
  fillEllipse(ctx, 0.36 * w, 0.02 * ht, 0.3 * w, 0.1 * ht, css(furDark));
  fillEllipse(ctx, 0.32 * w, 0.04 * ht, 0.36 * w, 0.44 * ht, css(f));
  stroke(ctx, [p(0.46, 0.2), p(0.58, 0.42), p(0.7, 0.6)], 0.3 * w, css(f), 0.85, 0.6);
  stroke(ctx, [p(0.56, 0.16), p(0.66, 0.36), p(0.72, 0.5)], 0.13 * w, css(Pl.peach), 0.4, 0.3);
  stroke(ctx, [p(0.68, 0.42), p(0.78, 0.4), p(0.83, 0.44)], 0.07 * w, css(furDark), 0.8, 0.5);
  fillEllipse(ctx, 0.62 * w, 0.54 * ht, 0.27 * w, 0.3 * ht, css(f));
  stroke(ctx, [p(0.7, 0.78), p(0.69, 0.88), p(0.66, 0.97)], 0.09 * w, css(furDark), 0.9, 0.2);
  fillEllipse(ctx, 0.8 * w, 0.58 * ht, 0.17 * w, 0.16 * ht, css(f));
  fillEllipse(ctx, 0.82 * w, 0.57 * ht, 0.11 * w, 0.08 * ht, css(Pl.peach));
  fillEllipse(ctx, 0.79 * w, 0.7 * ht, 0.055 * w, 0.065 * ht, css(Pl.shadowInk));
  fillEllipse(ctx, 0.94 * w, 0.66 * ht, 0.05 * w, 0.05 * ht, css(Pl.shadowInk));
  fillEllipse(ctx, 0.795 * w, 0.74 * ht, 0.018 * w, 0.02 * ht, css(Pl.peach));
}

function drawSquirrelTail(ctx, Pl, h) {
  const b = squirrelBody(h);
  ctx.translate(squirrelRoom(h).w, 0);
  const w = b.w, ht = b.h;
  const p = (x, y) => P(x * w, y * ht);
  stroke(ctx, [p(0.38, 0.2), p(0.02, 0.2), p(0.02, 0.92), p(0.34, 0.86)], 0.3 * w, css(mix(fur(Pl), Pl.orange, 0.2)), 0.5, 0.25);
  stroke(ctx, [p(0.3, 0.26), p(0.1, 0.3), p(0.1, 0.82), p(0.3, 0.82)], 0.1 * w, css(mix(Pl.mustard, Pl.orange, 0.3)), 0.3, 0.1);
}

// ---------- Smash bits ----------

function drawShard(ctx, Pl, kind, size, variant) {
  const r = rng(variant * 104729 + 17);
  const look = pumpkinLook(kind, Pl);
  const c = P(size / 2, size / 2);
  const points = 5 + (variant % 3);
  const pts = [];
  for (let k = 0; k < points; k++) {
    const a = (k / points) * TAU + r.float(-0.25, 0.25);
    const rad = size * 0.5 * r.float(0.55, 0.98);
    pts.push(P(c.x + Math.cos(a) * rad, c.y + Math.sin(a) * rad));
  }
  fillPoly(ctx, pts, css(variant % 3 === 0 ? look.side : look.body));
  ctx.save();
  poly(ctx, pts);
  ctx.clip();
  fillRect(ctx, 0, 0, size, size * 0.26, css(Pl.peach, 0.7));
  ctx.restore();
}

function drawSeed(ctx, Pl) {
  ctx.beginPath();
  ctx.moveTo(1.6, 0.2);
  ctx.quadraticCurveTo(3.4, 2.2, 1.6, 4.8);
  ctx.quadraticCurveTo(-0.2, 2.2, 1.6, 0.2);
  ctx.fillStyle = css(Pl.seed);
  ctx.fill();
}

function drawSplat(ctx, Pl, kind, width) {
  const ht = width * 0.32;
  const r = rng(Math.round(width) + 99);
  const body = css(pumpkinLook(kind, Pl).body, 0.85);
  fillEllipse(ctx, width * 0.12, ht * 0.1, width * 0.76, ht * 0.75, body);
  for (let i = 0; i < 9; i++) {
    const rr = r.float(width * 0.04, width * 0.1);
    const x = r.float(width * 0.05, width * 0.95);
    const y = r.float(ht * 0.1, ht * 0.75);
    fillEllipse(ctx, x - rr, y - rr * 0.6, rr * 2, rr * 1.2, body);
  }
  for (let i = 0; i < 6; i++) fillEllipse(ctx, r.float(width * 0.2, width * 0.8), r.float(ht * 0.25, ht * 0.65), 2.2, 1.4, css(Pl.seed));
}

function drawSteam(ctx, Pl, w, ht, h, variant) {
  const dir = variant % 2 === 0 ? 1 : -1;
  stroke(ctx, [P(w / 2, 2), P(w / 2 + dir * w * 0.45, ht * 0.35), P(w / 2 - dir * w * 0.45, ht * 0.65), P(w / 2, ht - 2)], Math.max(1.5, h * 0.045), css(Pl.peach), 0.3, 0.05);
}

// ---------- Images ----------

const SCALE = 2.5;
const cache = new Map();
function image(key, w, h, draw) {
  const hit = cache.get(key);
  if (hit) return hit;
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.ceil(w * SCALE));
  canvas.height = Math.max(1, Math.ceil(h * SCALE));
  const ctx = canvas.getContext('2d');
  // Bottom-left origin, like the app's CoreGraphics contexts.
  ctx.setTransform(SCALE, 0, 0, -SCALE, 0, canvas.height);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  draw(ctx);
  const out = { url: canvas.toDataURL('image/png'), w, h };
  cache.set(key, out);
  return out;
}

export function pumpkinImage(kind, height, variant, look) {
  const size = pumpkinSize(kind, height);
  const body = bodySize(kind, height);
  return image(`p-${kind}-${height}-${variant}-${look}`, size.w, size.h, ctx => drawPumpkin(ctx, palette(look), kind, size.w / 2, PAD, body.w, body.h, variant));
}

export function decorImage(kind, unit, variant, look) {
  const s = decorSize(kind, unit);
  return image(`d-${kind}-${unit}-${variant}-${look}`, s.w, s.h, ctx => {
    const Pl = palette(look);
    const r = rng((variant + 1) * 4241 + kind.length);
    if (kind === 'hayBale') drawHayBale(ctx, Pl, s.w, s.h, unit, r);
    else if (kind === 'leafPile') drawLeafPile(ctx, Pl, s.w, s.h, unit, r);
    else if (kind === 'acorns') drawAcorns(ctx, Pl, s.w, s.h, unit);
    else if (kind === 'mug') drawMug(ctx, Pl, s.w, s.h);
    else if (kind === 'lantern') drawLantern(ctx, Pl, s.w, s.h, unit);
    else if (kind === 'apples') drawApples(ctx, Pl, s.w, s.h, unit, r);
  });
}

export function vineImage(width, height, seed, k, look) {
  return image(`v-${width}-${height}-${seed}-${k}-${look}`, width, height, ctx => drawVine(ctx, palette(look), width, seed, k));
}

export function leafImage(kind, size, variant, look) {
  return image(`l-${kind}-${size}-${variant}-${look}`, size, size, ctx => drawWagonLeaf(ctx, palette(look), kind, P(size * 0.54, size * 0.54), size * 0.78, 45, variant % 2 === 1));
}

export function squirrelImages(h, look) {
  const s = squirrelSize(h);
  return {
    body: image(`sq-${h}-${look}`, s.w, s.h, ctx => drawSquirrel(ctx, palette(look), h)),
    tail: image(`sqt-${h}-${look}`, s.w, s.h, ctx => drawSquirrelTail(ctx, palette(look), h)),
  };
}

export function acornImage(s, look) {
  return image(`a-${s}-${look}`, s * 0.8, s, ctx => acorn(ctx, palette(look), P((s * 0.8) / 2, 0.5), s * 0.95, 0));
}

export function steamImage(h, variant, look) {
  const w = Math.round(h * 0.16), ht = Math.round(h * 0.36);
  return image(`st-${h}-${variant}-${look}`, w, ht, ctx => drawSteam(ctx, palette(look), w, ht, h, variant));
}

export function shardImage(kind, size, variant, look) {
  return image(`sh-${kind}-${size}-${variant}-${look}`, size, size, ctx => drawShard(ctx, palette(look), kind, size, variant));
}

export function seedImage(look) {
  return image(`seed-${look}`, 3.2, 5, ctx => drawSeed(ctx, palette(look)));
}

export function splatImage(kind, width, look) {
  return image(`sp-${kind}-${width}-${look}`, width, width * 0.32, ctx => drawSplat(ctx, palette(look), kind, width));
}
