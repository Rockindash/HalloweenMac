import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  BALE_KINDS, LANTERN_FLAME, LATTE_STEAM, LEAF_KINDS, PUMPKIN_KINDS, acornImage, css, decorImage, decorSize, leafImage, palette,
  pumpkinImage, pumpkinSize, rng, seedImage, shardImage, splatImage, squirrelImages, squirrelPaws, squirrelSize, steamImage, tailBase,
  vineBase, vineImage,
} from './harvest.js';

// Layout rules from the app (PumpkinScene.layoutSlots): pumpkins are 90 pt tall whatever the Dock's
// size, decorations are drawn at 75%, every fifth pumpkin from the third sits on a hay bale, and the
// leftover room is spread evenly between everything.
export const ITEM_H = 90;
const DECOR_UNIT = Math.round(ITEM_H * 0.75);
const K = ITEM_H / 60;
const SPACING = { few: 0.9, plenty: 0.16, overflowing: 0.03 };
const GAP_CYCLE = ['leafPile', 'acorns', 'mug', 'apples', 'leafPile', 'lantern', 'acorns', 'apples', 'leafPile', 'acorns'];

function decorKind(gaps, gap, start) {
  const kind = GAP_CYCLE[(start + gap) % GAP_CYCLE.length];
  if ((kind === 'mug' || kind === 'lantern') && gaps.slice(-8).some(g => g.kind === kind)) return 'leafPile';
  return kind;
}

export function layoutHarvest(dockW, fullness, extras, seed) {
  const minSpace = ITEM_H * SPACING[fullness];
  const bale = decorSize('hayBale', ITEM_H);
  // The app starts the cycle anywhere; the page starts where the latte and lantern both fit a short Dock.
  const decorStart = 1 + (seed % 2);
  const slots = [], gaps = [], widths = [];
  let used = 0;
  for (let slot = 0; slot < 200; slot++) {
    let gapKind = null, gapW = 0;
    if (extras && slot > 0) {
      gapKind = decorKind(gaps, slot - 1, decorStart);
      gapW = decorSize(gapKind, DECOR_UNIT).w;
    }
    const onBale = extras && slot % 5 === 2;
    const r = rng((slot + 1) * 7537 + seed);
    const scale = onBale ? r.float(0.76, 0.82) : slot % 3 === 1 ? r.float(0.82, 0.88) : r.float(0.92, 1);
    const kinds = onBale ? BALE_KINDS : PUMPKIN_KINDS;
    const kind = kinds[Math.floor(rng(seed * 31 + slot * 2654435761).next() * kinds.length)];
    const height = Math.round(ITEM_H * scale);
    const width = Math.max(onBale ? bale.w : 0, pumpkinSize(kind, height).w);
    const items = widths.length + (gapKind ? 2 : 1);
    if (used + gapW + width + (items + 1) * minSpace > dockW) break;
    if (gapKind) {
      gaps.push({ kind: gapKind, w: gapW });
      widths.push(gapW);
    }
    widths.push(width);
    slots.push({ kind, scale, height, onBale, perch: onBale ? bale.h * 0.86 : 0, variant: (seed + slot * 13) % 97 });
    used += gapW + width;
  }
  const space = (dockW - used) / (widths.length + 1);
  let x = space, si = 0, gi = 0;
  widths.forEach((w, i) => {
    if (!extras || i % 2 === 0) slots[si++].x = x + w / 2;
    else gaps[gi++].x = x + w / 2;
    x += w + space;
  });
  return { slots, gaps };
}

// ---------- Flying bits (smash chunks, seeds, leaves) ----------

let nextId = 1;
const G = 900; // SpriteKit gravity in the app: about 900 pt/s²

function makeBit(img, w, h, x, y, vx, vy, life, gravity = G) {
  const ys = [0.25, 0.5, 0.75, 1].map(q => {
    const t = life * q;
    return vy * t - (gravity * t * t) / 2;
  });
  return { id: nextId++, url: img.url, w, h, x, y, dx: vx * life, ys, life, spin: (Math.random() - 0.5) * 720 };
}

function Bits({ bits, u }) {
  return bits.map(b => (
    <span
      key={b.id}
      className="bit"
      style={{
        left: u(b.x - b.w / 2),
        bottom: u(b.y - b.h / 2),
        width: u(b.w),
        '--dx': u(b.dx),
        '--life': `${b.life}s`,
        '--spin': `${b.spin}deg`,
        '--y1': u(-b.ys[0]),
        '--y2': u(-b.ys[1]),
        '--y3': u(-b.ys[2]),
        '--y4': u(-b.ys[3]),
      }}
    >
      <img src={b.url} alt="" />
    </span>
  ));
}

const rand = (a, b) => a + Math.random() * (b - a);

// ---------- Squirrel ----------

function Squirrel({ layout, dockW, look, u, liftAt, enabled }) {
  const h = ITEM_H;
  const size = squirrelSize(h);
  const art = squirrelImages(h, look);
  const acorn = acornImage(Math.round(h * 0.14), look);
  const paws = squirrelPaws(h);
  const tb = tailBase(h);
  const [s, setS] = useState({ x: 0, facing: 1, show: false, holding: false, hop: 0, hopH: 0, dur: 200 });
  const token = useRef({ timers: [], dead: false });
  const acornsAt = layout.gaps.filter(g => g.kind === 'acorns').map(g => g.x);
  const acornsKey = acornsAt.join(',');

  const cancel = () => {
    token.current.dead = true;
    token.current.timers.forEach(clearTimeout);
    token.current = { timers: [], dead: false };
    return token.current;
  };

  const run = useCallback(
    async (tk, plan) => {
      const wait = ms =>
        new Promise((res, rej) => {
          tk.timers.push(setTimeout(() => (tk.dead ? rej() : res()), ms));
        });
      const hops = async (x0, x1, stepMs) => {
        const count = Math.max(1, Math.round(Math.abs(x1 - x0) / (h * 0.42)));
        for (let i = 1; i <= count; i++) {
          setS(p => ({ ...p, x: x0 + ((x1 - x0) * i) / count, hop: p.hop + 1, hopH: h * 0.16, dur: stepMs }));
          await wait(stepMs);
        }
      };
      try {
        await plan({ wait, hops });
      } catch {
        /* cancelled */
      }
    },
    [h]
  );

  const schedule = useCallback(
    (first, tk) => {
      tk.timers.push(
        setTimeout(() => {
          if (tk.dead) return;
          const fromLeft = Math.random() < 0.5;
          const startX = fromLeft ? h * 0.3 : dockW - h * 0.3;
          const endX = fromLeft ? dockW - h * 0.3 : h * 0.3;
          const dir = fromLeft ? 1 : -1;
          const spot = acornsAt.length ? acornsAt[Math.floor(Math.random() * acornsAt.length)] : null;
          run(tk, async ({ wait, hops }) => {
            setS(p => ({ ...p, x: startX, facing: dir, show: true, holding: false, dur: 0 }));
            await wait(250);
            if (spot == null) {
              await hops(startX, endX, 260);
            } else {
              const stopX = spot - dir * h * 0.32;
              await hops(startX, stopX, 260);
              await wait(300);
              setS(p => ({ ...p, hop: p.hop + 1, hopH: -h * 0.04, dur: 500 }));
              await wait(250);
              setS(p => ({ ...p, holding: true }));
              await wait(550);
              for (let i = 0; i < 7; i++) {
                setS(p => ({ ...p, hop: p.hop + 1, hopH: h * 0.025, dur: 280 }));
                await wait(280);
              }
              await wait(600);
              setS(p => ({ ...p, facing: -dir }));
              await wait(700);
              setS(p => ({ ...p, facing: dir }));
              await wait(400);
              setS(p => ({ ...p, facing: -dir }));
              await wait(200);
              await hops(stopX, startX, 260);
            }
            setS(p => ({ ...p, show: false }));
            await wait(300);
            schedule(false, tk);
          });
        }, first ? 2500 : rand(22000, 38000))
      );
    },
    [acornsKey, dockW, h, run] // eslint-disable-line react-hooks/exhaustive-deps
  );

  useEffect(() => {
    const tk = cancel();
    setS(p => ({ ...p, show: false }));
    if (enabled) schedule(true, tk);
    return () => cancel();
  }, [enabled, schedule]); // eslint-disable-line react-hooks/exhaustive-deps

  // It runs off when the pointer comes close, like in the app.
  const flee = () => {
    if (!s.show) return;
    const tk = cancel();
    const toRight = s.x > dockW / 2;
    const edge = toRight ? dockW - h * 0.3 : h * 0.3;
    run(tk, async ({ wait, hops }) => {
      setS(p => ({ ...p, facing: toRight ? 1 : -1 }));
      await hops(s.x, edge, 140);
      setS(p => ({ ...p, show: false }));
      await wait(300);
      schedule(false, tk);
    });
  };

  if (!enabled) return null;
  return (
    <span
      className={`squirrel ${s.show ? 'on' : ''}`}
      style={{ left: u(s.x), bottom: u(-2), width: u(size.w), '--lift': `${-liftAt(s.x)}cqw`, '--dur': `${s.dur}ms` }}
      onPointerEnter={flee}
      aria-hidden="true"
    >
      <span key={s.hop} className="sq-hop" style={{ '--hop': u(-s.hopH), '--dur': `${s.dur}ms` }}>
        <span className="sq-face" style={{ transform: `scaleX(${s.facing})` }}>
          <img className="sq-tail" src={art.tail.url} alt="" style={{ transformOrigin: `${tb.x * 100}% ${(1 - tb.y) * 100}%` }} />
          <img src={art.body.url} alt="" />
          {s.holding && (
            <img
              className="sq-acorn"
              src={acorn.url}
              alt=""
              style={{ width: u(acorn.w), left: `calc(50% + ${u(paws.x - acorn.w / 2)})`, bottom: u(paws.y - acorn.h * 0.3) }}
            />
          )}
        </span>
      </span>
    </span>
  );
}

// ---------- The harvest ----------

export default function Harvest({ look, extras, fullness, seed, dockLeft, dockW, PT, liftAtCqw, onSmash, reduced }) {
  const u = useCallback(v => `${(v * PT).toFixed(3)}cqw`, [PT]);
  const dockPt = dockW / PT;
  const layout = useMemo(() => layoutHarvest(dockPt, fullness, extras, seed), [dockPt, fullness, extras, seed]);
  const liftAt = x => liftAtCqw(dockLeft + x * PT);
  const [smashed, setSmashed] = useState({}); // slot -> generation
  const [gone, setGone] = useState({});
  const [poked, setPoked] = useState({});
  const [bits, setBits] = useState([]);
  const timers = useRef([]);
  useEffect(() => () => timers.current.forEach(clearTimeout), []);
  useEffect(() => {
    setGone({});
    setSmashed({});
  }, [seed]);
  const later = (ms, fn) => timers.current.push(setTimeout(fn, ms));

  const spawn = list => {
    setBits(b => [...b, ...list]);
    const ids = new Set(list.map(x => x.id));
    later(Math.max(...list.map(x => x.life)) * 1000 + 3200, () => setBits(b => b.filter(x => !ids.has(x.id))));
  };

  const flutter = (count, x, y, size, spread, up) =>
    Array.from({ length: count }, (_, i) =>
      makeBit(leafImage(LEAF_KINDS[i % 4], size, i, look), size, size, x + rand(-spread, spread), y, rand(-60, 60), rand(up[0], up[1]), 2.2, 260)
    );

  const smash = (slot, p, bottom) => {
    if (gone[slot]) return;
    setGone(g => ({ ...g, [slot]: true }));
    onSmash();
    const img = pumpkinImage(p.kind, p.height, p.variant, look);
    const cy = bottom + img.h * 0.35;
    const list = [];
    const sw = Math.round(img.w * 1.15);
    const splat = splatImage(p.kind, sw, look);
    list.push({ id: nextId++, splat: true, url: splat.url, w: sw, h: splat.h, x: p.x, y: bottom + 2 - splat.h * 0.35 + splat.h / 2, life: 2.9 });
    if (!reduced) {
      for (let i = 0; i < 11; i++) {
        const s = Math.round(img.h * rand(0.18, 0.3));
        list.push(makeBit(shardImage(p.kind, s, i % 6, look), s, s, p.x + rand(-img.w * 0.3, img.w * 0.3), cy, rand(-190, 190), rand(160, 380), 1.1));
      }
      const k = img.h / 40;
      for (let i = 0; i < 9; i++) list.push(makeBit(seedImage(look), 3.2 * k, 5 * k, p.x + rand(-img.w * 0.2, img.w * 0.2), cy, rand(-150, 150), rand(120, 300), 1.0));
      list.push(...flutter(2, p.x, cy, Math.round(img.h * 0.26), 4, [220, 320]));
    }
    spawn(list);
    later(3000, () => {
      setSmashed(m => ({ ...m, [slot]: (m[slot] || 0) + 1 }));
      setGone(g => ({ ...g, [slot]: false }));
    });
  };

  const poke = (key, kind, x, w, h) => {
    setPoked(p => ({ ...p, [key]: (p[key] || 0) + 1 }));
    if (reduced) return;
    if (kind === 'leafPile') spawn(flutter(9, x, h * 0.8, Math.round(ITEM_H * 0.22), w * 0.3, [180, 320]));
  };

  // Vine: drawn once, shown as thin strips so it can bend up over magnified icons like the app's.
  const vineW = Math.round(dockPt - 8);
  const vineH = Math.round(ITEM_H * 1.25);
  const vine = vineImage(vineW, vineH, seed % 997, K, look);
  const strips = 90;
  const stripW = vineW / strips;
  const castInk = css(palette(look).shadowInk, look === 'dark' ? 0.24 : 0.16);
  const glow = palette(look).mustard;

  return (
    <div className="harvest" style={{ left: `${dockLeft}cqw`, width: `${dockW}cqw` }}>
      <div className="vine" aria-hidden="true">
        {Array.from({ length: strips }, (_, i) => (
          <span
            key={i}
            style={{
              left: u(4 + i * stripW),
              bottom: u(-2 - vineBase(K)),
              width: u(stripW + 0.6),
              height: u(vineH),
              backgroundImage: `url(${vine.url})`,
              backgroundSize: `${u(vineW)} ${u(vineH)}`,
              backgroundPosition: `-${u(i * stripW)} 0`,
              transform: `translateY(${-liftAt(4 + (i + 0.5) * stripW)}cqw)`,
            }}
          />
        ))}
      </div>

      {layout.slots.map((p, slot) =>
        p.onBale ? (
          <Decor key={`bale-${seed}-${slot}`} kind="hayBale" unit={ITEM_H} variant={slot} x={p.x} bottom={-3} z={1} look={look} u={u} lift={liftAt(p.x)} poked={poked[`b${slot}`]} onPoke={() => poke(`b${slot}`, 'hayBale', p.x, 0, 0)} />
        ) : null
      )}

      {layout.slots.map((p, slot) => {
        const img = pumpkinImage(p.kind, p.height, p.variant, look);
        const bottom = -3 - (p.perch > 0 ? 0 : (1 - p.scale) * 5) + p.perch;
        const bounce = p.onBale ? poked[`b${slot}`] : 0;
        return (
          <button
            key={`${seed}-${slot}-${smashed[slot] || 0}`}
            type="button"
            className={`hv pumpkin ${gone[slot] ? 'smashed' : ''}`}
            style={{ left: u(p.x), bottom: u(bottom), width: u(img.w), zIndex: 2 + Math.round((1.2 - p.scale) * 10), '--lift': `${-liftAt(p.x)}cqw` }}
            onClick={() => smash(slot, p, bottom)}
            disabled={!!gone[slot]}
            aria-label="Smash this pumpkin"
          >
            <span className="shadow" style={{ height: u(8), bottom: u(-2) }} />
            <span key={bounce || 0} className={`art ${bounce ? 'bounce' : ''}`}>
              <img src={img.url} alt="" style={{ filter: `drop-shadow(${u(3 * K)} ${u(1.5 * K)} 0 ${castInk})` }} />
            </span>
          </button>
        );
      })}

      {layout.gaps.map((g, i) => (
        <Decor key={`${seed}-${i}-${g.kind}`} kind={g.kind} unit={DECOR_UNIT} variant={i} x={g.x} bottom={-2} z={10} look={look} u={u} lift={liftAt(g.x)} poked={poked[`g${i}`]} glow={glow} reduced={reduced} onPoke={() => poke(`g${i}`, g.kind, g.x, g.w, decorSize(g.kind, DECOR_UNIT).h)} />
      ))}

      <Squirrel layout={layout} dockW={dockPt} look={look} u={u} liftAt={liftAt} enabled={extras && !reduced && dockPt > 300} />

      <div className="fx" aria-hidden="true">
        {bits.map(b =>
          b.splat ? (
            <img key={b.id} className="splat" src={b.url} alt="" style={{ left: u(b.x - b.w / 2), bottom: u(b.y - b.h / 2), width: u(b.w) }} />
          ) : null
        )}
        <Bits bits={bits.filter(b => !b.splat)} u={u} />
      </div>
    </div>
  );
}

const DECOR_LABEL = { hayBale: 'Hay bale', leafPile: 'Leaf pile', acorns: 'Acorns', mug: 'Pumpkin spice latte', lantern: 'Lantern', apples: 'Crate of apples' };

function Decor({ kind, unit, variant, x, bottom, z, look, u, lift, poked, onPoke, glow, reduced }) {
  const img = decorImage(kind, unit, variant, look);
  return (
    <button
      type="button"
      className={`hv decor ${kind}`}
      style={{ left: u(x), bottom: u(bottom), width: u(img.w), zIndex: z, '--lift': `${-lift}cqw` }}
      onClick={onPoke}
      aria-label={DECOR_LABEL[kind]}
    >
      {kind === 'lantern' && (
        <span
          key={`g${poked || 0}`}
          className={`glow ${poked ? 'flare' : ''}`}
          style={{
            width: u(Math.round(unit * 1.15)),
            bottom: u(img.h * LANTERN_FLAME - Math.round(unit * 1.15) / 2),
            background: `radial-gradient(closest-side, ${css(glow, 0.75)}, ${css(glow, 0.25)} 40%, ${css(glow, 0)})`,
          }}
        />
      )}
      {kind === 'mug' && !reduced && (
        <span key={`s${poked || 0}`} className={`steam ${poked ? 'strong' : ''}`} style={{ left: `calc(50% + ${u((LATTE_STEAM.x - 0.5) * img.w)})`, bottom: u(img.h * LATTE_STEAM.y) }}>
          {[0, 1, 2].map(i => {
            const s = steamImage(unit, i % 2, look);
            return <img key={i} src={s.url} alt="" style={{ width: u(s.w), marginLeft: u(-s.w / 2), animationDelay: `${i * 0.75}s`, '--rise': u(-unit * 0.36) }} />;
          })}
        </span>
      )}
      <span key={poked || 0} className={`art ${poked ? 'poke' : ''}`}>
        <img src={img.url} alt="" />
      </span>
    </button>
  );
}
