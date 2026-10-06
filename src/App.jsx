import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Harvest, { ITEM_H } from './Harvest.jsx';
import { LEAF_KINDS, leafImage, pumpkinImage } from './harvest.js';
import { DOCK_APPS, DOCK_STACKS, CalendarIcon } from './dockicons.jsx';

// ---------- Dock geometry (in container-width units, cqw) ----------
const S = 4.6; // icon size
const GAP = 0.45;
const PAD = 0.7;
const DIVIDER = 1.3; // divider plus its spacing
const ITEMS = [...DOCK_APPS.map(a => ({ ...a, kind: 'app' })), { kind: 'divider' }, ...DOCK_STACKS.map(a => ({ ...a, kind: 'stack' }))];
const ICONS = ITEMS.filter(i => i.kind !== 'divider');
const BASE_W = ICONS.length * S + (ICONS.length - 2) * GAP + DIVIDER + PAD * 2;
const BASE_LEFT = 50 - BASE_W / 2;
const MAG = 0.7; // max extra scale when magnified
const REACH = S * 2.6;

// centre of every icon in the resting Dock
const CENTERS = (() => {
  let x = BASE_LEFT + PAD;
  const out = [];
  ITEMS.forEach((it, i) => {
    if (it.kind === 'divider') {
      x += DIVIDER - GAP;
      return;
    }
    out.push(x + S / 2);
    x += S + (i < ITEMS.length - 1 ? GAP : 0);
  });
  return out;
})();

const magAt = (x, mouse) => {
  if (mouse == null) return 1;
  const d = Math.abs(x - mouse) / REACH;
  return d >= 1 ? 1 : 1 + MAG * (Math.cos(Math.PI * d) + 1) / 2;
};

const PT = 0.095; // one point on the Mac, in cqw: the app's 90 pt pumpkins stand about twice an icon's height
const reducedMotion = () => typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

function PumpkinPic({ kind = 'roundOrange', variant = 3, look = 'dark', className }) {
  const img = pumpkinImage(kind, ITEM_H, variant, look);
  return <img className={className} src={img.url} alt="" draggable="false" />;
}

function FallingLeaves({ on, look }) {
  const leaves = useMemo(
    () =>
      Array.from({ length: 14 }, (_, i) => ({
        left: Math.round(Math.random() * 96),
        delay: (Math.random() * 10).toFixed(1),
        dur: (9 + Math.random() * 6).toFixed(1),
        size: Math.round(17 + Math.random() * 8),
        kind: LEAF_KINDS[i % 4],
      })),
    []
  );
  if (!on) return null;
  return (
    <div className="leaves" aria-hidden="true">
      {leaves.map((l, i) => (
        <span key={i} style={{ left: `${l.left}%`, animationDelay: `-${l.delay}s`, animationDuration: `${l.dur}s`, width: `${l.size * PT}cqw` }}>
          <img src={leafImage(l.kind, 24, i, look).url} alt="" />
        </span>
      ))}
    </div>
  );
}

function Clock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(t);
  }, []);
  return (
    <span>
      {now.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}&nbsp;&nbsp;
      {now.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
    </span>
  );
}

function DockorateIcon() {
  return (
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <defs>
        <linearGradient id="dkr" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#7A2A3B" />
          <stop offset="1" stopColor="#4A1422" />
        </linearGradient>
      </defs>
      <rect x="4" y="4" width="92" height="92" rx="21" fill="url(#dkr)" />
    </svg>
  );
}

// A soft autumn landscape, so the harvest reads the way it does on a real wallpaper.
function Wallpaper({ look }) {
  const d = look === 'dark';
  const c = d
    ? { sky0: '#18203a', sky1: '#4a3550', far: '#2d3a45', mid: '#24322b', near: '#18231c', t1: '#6b3b25', t2: '#7a5a22', t3: '#3f4a26', sun: '#f3e6c4' }
    : { sky0: '#a9c4d3', sky1: '#f2d6b0', far: '#9bb08f', mid: '#6f8a55', near: '#4d6a3a', t1: '#c9772f', t2: '#d9a43a', t3: '#8a9a3f', sun: '#fff4dc' };
  // A tree line peeking over the middle hill.
  const ridge = [[0, 66], [35, 59], [70, 57], [115, 56], [160, 53]];
  const ridgeY = x => {
    const i = Math.max(0, ridge.findIndex(([px]) => px >= x) - 1);
    const [x0, y0] = ridge[i], [x1, y1] = ridge[i + 1] || ridge[i];
    return x1 === x0 ? y0 : y0 + ((y1 - y0) * (x - x0)) / (x1 - x0);
  };
  const trees = Array.from({ length: 46 }, (_, i) => {
    const x = i * 3.6 + ((i * 37) % 7) * 0.3;
    return [x, ridgeY(x) + 1.2, 2.1 + ((i * 53) % 10) * 0.16, ['t1', 't2', 't3', 't2', 't1', 't3'][i % 6]];
  });
  return (
    <svg className="wallpaper" viewBox="0 0 160 100" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
      <defs>
        <linearGradient id={`sky-${look}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={c.sky0} />
          <stop offset="0.75" stopColor={c.sky1} />
        </linearGradient>
      </defs>
      <rect width="160" height="100" fill={`url(#sky-${look})`} />
      <circle cx={d ? 124 : 118} cy={d ? 20 : 30} r={d ? 3.2 : 5} fill={c.sun} opacity={d ? 0.9 : 0.6} />
      <path d="M0 58 C20 46 38 50 56 45 C76 40 96 47 116 42 C134 38 148 44 160 41 V100 H0 Z" fill={c.far} />
      {trees.map(([x, y, r, t], i) => (
        <ellipse key={i} cx={x} cy={y} rx={r} ry={r * 1.2} fill={c[t]} opacity={d ? 0.75 : 0.95} />
      ))}
      <path d="M0 66 C24 56 44 62 70 57 C96 52 118 60 160 53 V100 H0 Z" fill={c.mid} />
      <path d="M0 80 C30 70 60 76 92 71 C120 67 140 72 160 68 V100 H0 Z" fill={c.near} />
    </svg>
  );
}

function Desktop({ leaves, extras, look, fullness, seed, onSmash }) {
  const ref = useRef(null);
  const [mouse, setMouse] = useState(null);
  const reduced = useMemo(reducedMotion, []);

  const onMove = e => {
    const r = ref.current.getBoundingClientRect();
    const x = ((e.clientX - r.left) / r.width) * 100;
    const yFromBottom = ((r.bottom - e.clientY) / r.width) * 100;
    setMouse(yFromBottom < 8 && x > BASE_LEFT - 2 && x < BASE_LEFT + BASE_W + 2 ? x : null);
  };

  // Dock widens as icons magnify, centred like the real one.
  const scales = CENTERS.map(c => magAt(c, mouse));
  const extraW = scales.reduce((s, k) => s + (k - 1) * S, 0);
  const hovered = mouse == null ? -1 : scales.indexOf(Math.max(...scales));
  // Where the hovered icon sits in the magnified Dock, for its label.
  let label = null;
  if (hovered >= 0) {
    let x = 50 - (BASE_W + extraW) / 2 + PAD;
    let n = -1;
    ITEMS.forEach((it, i) => {
      if (it.kind === 'divider') {
        x += DIVIDER - GAP;
        return;
      }
      n += 1;
      if (n === hovered) label = { name: it.name, x: x + (S * scales[n]) / 2, h: S * scales[n] };
      x += S * scales[n] + (i < ITEMS.length - 1 ? GAP : 0);
    });
  }
  const liftAtCqw = useCallback(x => (magAt(x, mouse) - 1) * S, [mouse]);

  let iconIndex = -1;
  return (
    <div className={`desktop ${look}`} ref={ref} onPointerMove={onMove} onPointerLeave={() => setMouse(null)} role="group" aria-label="Interactive preview of Dockorate on a Mac">
      <Wallpaper look={look} />
      <div className="menubar">
        <b>Finder</b>
        <span>File</span>
        <span>Edit</span>
        <span>View</span>
        <span>Go</span>
        <span className="hide-sm">Window</span>
        <span className="hide-sm">Help</span>
        <span className="spacer" />
        <span className="mb-pumpkin" title="Dockorate">
          <PumpkinPic />
        </span>
        <Clock />
      </div>
      <FallingLeaves on={leaves} look={look} />

      <Harvest look={look} extras={extras} fullness={fullness} seed={seed} dockLeft={BASE_LEFT} dockW={BASE_W} PT={PT} liftAtCqw={liftAtCqw} onSmash={onSmash} reduced={reduced} />

      <div className="dock" style={{ width: `${BASE_W + extraW}cqw` }}>
        {ITEMS.map(it => {
          if (it.kind === 'divider') return <span key="div" className="divider" />;
          iconIndex += 1;
          const k = scales[iconIndex];
          return (
            <span key={it.name} className="icon" style={{ width: `${S * k}cqw` }}>
              {it.calendar ? <CalendarIcon /> : it.dockorate ? <DockorateIcon /> : it.icon}
              {it.running && <span className="dot" />}
            </span>
          );
        })}
      </div>
      {label && (
        <span className="label" style={{ left: `${label.x}cqw`, bottom: `calc(0.6cqw + ${PAD}cqw + 1px + ${label.h}cqw + 1.2cqw)` }}>
          {label.name}
        </span>
      )}
    </div>
  );
}

function Seg({ label, value, options, onChange }) {
  return (
    <div className="control">
      <span className="clabel">{label}</span>
      <div className="seg" role="radiogroup" aria-label={label}>
        {options.map(([v, text]) => (
          <button key={v} type="button" role="radio" aria-checked={value === v} className={value === v ? 'on' : ''} onClick={() => onChange(v)}>
            {text}
          </button>
        ))}
      </div>
    </div>
  );
}

function Switch({ id, label, checked, onChange }) {
  return (
    <label className="control switch" htmlFor={id}>
      <span className="clabel">{label}</span>
      <input id={id} type="checkbox" checked={checked} onChange={e => onChange(e.target.checked)} />
      <span className="track" aria-hidden="true" />
    </label>
  );
}

// Placeholder until the store link is ready.
const BUY_URL = '#buy';
const SUPPORT = 'support@amolkmr.com';

const FAQ = [
  ['Will it slow my Mac down?', 'No. Dockorate idles at about half a percent of one CPU core, and it sleeps while your Dock is hidden.'],
  ['Does my Dock still work?', 'Yes. The harvest sits along the top edge of your Dock, and your apps open and close as usual.'],
  ['Why does it ask for Accessibility?', 'Only to read the size of your Dock so the pumpkins fit it exactly. It’s optional; without it, Dockorate estimates the size.'],
  ['What about full-screen apps?', 'When your Dock hides, the pumpkins hide with it, and they come back when the Dock does.'],
  ['Can I put my Dock on the left or right?', 'Not yet. Version 1 decorates a Dock at the bottom of the screen.'],
  ['How do I get help?', `Email ${SUPPORT} and we’ll get back to you.`],
];

export default function App() {
  const [fill, setFill] = useState('plenty');
  const [leaves, setLeaves] = useState(true);
  const [extras, setExtras] = useState(true);
  const [look, setLook] = useState('light');
  const [smashed, setSmashed] = useState(0);
  const [seed, setSeed] = useState(() => 1 + Math.floor(Math.random() * 1e6));

  const onSmash = useCallback(() => setSmashed(s => s + 1), []);

  return (
    <>
      <header className="nav">
        <div className="nav-in">
          <a className="brand" href="#top">
            <span className="brand-mark">
              <PumpkinPic />
            </span>
            Dockorate
          </a>
          <nav>
            <a href="#highlights">Highlights</a>
            <a href="#faq">FAQ</a>
          </nav>
          <a className="btn small" href={BUY_URL}>
            Buy Now
          </a>
        </div>
      </header>

      <main id="top">
        <section className="hero">
          <p className="product">Dockorate</p>
          <h1>Your Dock, in season.</h1>
          <p className="lede">Decorate your Dock for every season. It starts with fall.</p>
          <div className="cta-row">
            <a className="btn" href={BUY_URL}>
              Buy Now
            </a>
            <a className="link" href="#try">
              Try it below ›
            </a>
          </div>
        </section>

        <section className="stage" id="try">
          <Desktop leaves={leaves} extras={extras} look={look} fullness={fill} seed={seed} onSmash={onSmash} />
          <p className="hint">
            Move your pointer along the Dock, and click a pumpkin to smash it. <span className="tally">{smashed} smashed</span>
          </p>
          <div className="controls" aria-label="Change the preview">
            <Seg label="How full" value={fill} onChange={setFill} options={[['few', 'A Few'], ['plenty', 'Plenty'], ['overflowing', 'Overflowing']]} />
            <Switch id="leaves" label="Falling leaves" checked={leaves} onChange={setLeaves} />
            <Switch id="extras" label="Cozy extras" checked={extras} onChange={setExtras} />
            <Seg label="Appearance" value={look} onChange={setLook} options={[['light', 'Light'], ['dark', 'Dark']]} />
            <button type="button" className="btn-secondary" onClick={() => setSeed(1 + Math.floor(Math.random() * 1e6))}>
              Grow New Pumpkins
            </button>
          </div>
        </section>

        <section className="highlights" id="highlights">
          <div className="hl-head">
            <h2>Get the highlights.</h2>
            <a className="btn" href={BUY_URL}>
              Buy Now
            </a>
          </div>
          <div className="bento">
            <article className="tile big warm">
              <p className="kicker">Smash</p>
              <h3>Go ahead. Smash one.</h3>
              <p>Click a pumpkin and it bursts into chunks and seeds, then grows back a few seconds later. Dockorate counts every smash.</p>
              <div className="tile-art smash-art" aria-hidden="true">
                <PumpkinPic kind="tallOrange" variant={1} />
                <PumpkinPic kind="roundMustard" variant={2} />
                <PumpkinPic kind="butternutOrange" variant={4} />
              </div>
            </article>
            <article className="tile">
              <p className="kicker">Fit</p>
              <h3>Made to measure.</h3>
              <p>The harvest stretches with your Dock, rises when icons magnify and hides when the Dock does, even in full-screen apps.</p>
            </article>
            <article className="tile dark">
              <p className="stat">0.5%</p>
              <p>CPU when idle. It lives in your menu bar and stays out of the way.</p>
            </article>
            <article className="tile">
              <p className="kicker">Appearance</p>
              <h3>Light and Dark.</h3>
              <p>A softer palette by day, a deeper one at night. It follows your Mac, and Reduce Motion too.</p>
              <div className="swatches" aria-hidden="true">
                <span style={{ background: '#F58A3A' }} />
                <span style={{ background: '#EDB54C' }} />
                <span style={{ background: '#7C9440' }} />
                <span style={{ background: '#EB6C15' }} />
                <span style={{ background: '#DB9D24' }} />
                <span style={{ background: '#627329' }} />
              </div>
            </article>
            <article className="tile wide">
              <p className="kicker">Details</p>
              <h3>Little surprises.</h3>
              <p>A squirrel stops by for an acorn. Hay bales squish when you tap them. The latte steams.</p>
            </article>
          </div>
        </section>

        <section className="steps">
          <h2>Ready in a minute.</h2>
          <ol>
            <li>
              <b>Open Dockorate.</b> Pumpkins appear on your Dock right away.
            </li>
            <li>
              <b>Allow Accessibility</b> for a perfect fit. This step is optional.
            </li>
            <li>
              <b>Make it yours</b> from the pumpkin in your menu bar.
            </li>
          </ol>
        </section>

        <section className="faq" id="faq">
          <h2>Questions?</h2>
          <div>
            {FAQ.map(([q, a]) => (
              <details key={q}>
                <summary>{q}</summary>
                <p>{a}</p>
              </details>
            ))}
          </div>
        </section>
      </main>

      <section className="get" id="buy">
        <h2>Bring the harvest to your Dock.</h2>
        <p>Dockorate for Mac. Pumpkins, a squirrel and a latte, all in one tiny app.</p>
        <a className="btn" href={BUY_URL}>
          Buy Now
        </a>
        <p className="contact">Additional questions?</p>
        <a className="btn-ghost" href={`mailto:${SUPPORT}`}>
          Contact Us
        </a>
      </section>

      <footer>
        <div className="foot-in">
          <p>Dockorate decorates a Dock at the bottom of the screen. Requires a Mac.</p>
          <p>Copyright © 2026 Amol Kumar. All rights reserved.</p>
        </div>
      </footer>
    </>
  );
}
