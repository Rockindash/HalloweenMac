// Blank macOS-style Dock icons: each app's tile colour with no symbol on it (no Apple artwork used).
const G = ({ id, a, b, x2 = 0, y2 = 1 }) => (
  <linearGradient id={id} x1="0" y1="0" x2={x2} y2={y2}>
    <stop offset="0" stopColor={a} />
    <stop offset="1" stopColor={b} />
  </linearGradient>
);
// The symbols inside each tile are left out on purpose, so the Dock shows blank icons.
const Tile = ({ fill, grad }) => (
  <svg viewBox="0 0 100 100" aria-hidden="true">
    <defs>{grad}</defs>
    <rect x="4" y="4" width="92" height="92" rx="21" fill={fill} />
  </svg>
);

export const DOCK_APPS = [
  {
    name: 'Finder',
    running: true,
    icon: (
      <Tile fill="url(#fnd)" grad={<G id="fnd" a="#6EC1FF" b="#1F7BF2" />}>
        <path d="M50 4 C44 30 44 60 52 96 H75 A21 21 0 0 0 96 75 V25 A21 21 0 0 0 75 4 Z" fill="#E9F3FF" />
        <path d="M50 4 C44 30 44 60 52 96" stroke="#1B3A66" strokeWidth="3" fill="none" />
        <rect x="31" y="32" width="5" height="14" rx="2.5" fill="#1B3A66" />
        <rect x="66" y="32" width="5" height="14" rx="2.5" fill="#1B3A66" />
        <path d="M27 66 Q50 80 74 66" stroke="#1B3A66" strokeWidth="4" fill="none" strokeLinecap="round" />
      </Tile>
    ),
  },
  {
    name: 'Safari',
    running: true,
    icon: (
      <Tile fill="#F5F7FA">
        <defs><G id="saf" a="#3FB6FF" b="#0A6FE0" /></defs>
        <circle cx="50" cy="50" r="38" fill="url(#saf)" />
        <circle cx="50" cy="50" r="34" fill="none" stroke="#fff" strokeWidth="1.5" strokeDasharray="1 4.3" opacity="0.8" />
        <path d="M50 50 L72 28 L56 56 Z" fill="#FF3B30" />
        <path d="M50 50 L28 72 L44 44 Z" fill="#fff" />
      </Tile>
    ),
  },
  {
    name: 'Messages',
    running: true,
    icon: (
      <Tile fill="url(#msg)" grad={<G id="msg" a="#6CF27E" b="#18BC3A" />}>
        <path d="M50 24 C29 24 18 36 18 49 C18 57 23 64 31 68 C30 73 27 77 23 80 C31 80 37 77 41 73 C44 74 47 74 50 74 C71 74 82 62 82 49 C82 36 71 24 50 24 Z" fill="#fff" />
      </Tile>
    ),
  },
  {
    name: 'Mail',
    icon: (
      <Tile fill="url(#mail)" grad={<G id="mail" a="#5AC8FF" b="#1580F0" />}>
        <rect x="20" y="30" width="60" height="42" rx="5" fill="#fff" />
        <path d="M21 32 L50 55 L79 32" stroke="#7FB8F0" strokeWidth="3" fill="none" />
      </Tile>
    ),
  },
  {
    name: 'Maps',
    icon: (
      <Tile fill="#CFE8C2">
        <path d="M4 60 L60 4 H75 A21 21 0 0 1 96 25 V30 L30 96 H25 A21 21 0 0 1 4 75 Z" fill="#F6F1E4" />
        <path d="M14 96 L96 14" stroke="#F7C948" strokeWidth="9" />
        <path d="M4 44 Q40 52 56 96" stroke="#fff" strokeWidth="6" fill="none" />
        <circle cx="64" cy="40" r="11" fill="#FF3B30" />
        <circle cx="64" cy="40" r="4.5" fill="#fff" />
      </Tile>
    ),
  },
  {
    name: 'Photos',
    icon: (
      <Tile fill="#fff">
        {['#FF9500', '#FFCC00', '#A5D63F', '#34C759', '#5AC8FA', '#007AFF', '#AF52DE', '#FF2D55'].map((c, i) => (
          <ellipse key={c} cx="50" cy="31" rx="10" ry="17" fill={c} opacity="0.85" transform={`rotate(${i * 45} 50 50)`} />
        ))}
      </Tile>
    ),
  },
  {
    name: 'Music',
    icon: (
      <Tile fill="url(#mus)" grad={<G id="mus" a="#FF6B81" b="#FA233B" />}>
        <path d="M42 30 L68 25 V61" stroke="#fff" strokeWidth="5" fill="none" strokeLinejoin="round" />
        <path d="M42 30 V67" stroke="#fff" strokeWidth="5" />
        <ellipse cx="36" cy="68" rx="8" ry="6.5" fill="#fff" />
        <ellipse cx="62" cy="62" rx="8" ry="6.5" fill="#fff" />
      </Tile>
    ),
  },
  {
    name: 'FaceTime',
    icon: (
      <Tile fill="url(#ft)" grad={<G id="ft" a="#6CF27E" b="#18BC3A" />}>
        <rect x="20" y="34" width="40" height="32" rx="8" fill="#fff" />
        <path d="M62 46 L80 35 V65 L62 54 Z" fill="#fff" />
      </Tile>
    ),
  },
  {
    name: 'Calendar',
    calendar: true,
  },
  {
    name: 'Notes',
    icon: (
      <Tile fill="#FFFDF4">
        <path d="M4 25 V25 A21 21 0 0 1 25 4 H75 A21 21 0 0 1 96 25 V30 H4 Z" fill="#FFD52E" />
        {[44, 56, 68, 80].map(y => (
          <path key={y} d={`M16 ${y} H84`} stroke="#E4DFCF" strokeWidth="2" />
        ))}
      </Tile>
    ),
  },
  {
    name: 'Podcasts',
    icon: (
      <Tile fill="url(#pod)" grad={<G id="pod" a="#D17BFF" b="#8E2DE2" />}>
        <circle cx="50" cy="45" r="27" fill="none" stroke="#fff" strokeWidth="5" />
        <circle cx="50" cy="45" r="15" fill="none" stroke="#fff" strokeWidth="5" />
        <circle cx="50" cy="45" r="6" fill="#fff" />
        <rect x="45" y="55" width="10" height="27" rx="5" fill="#fff" />
      </Tile>
    ),
  },
  {
    name: 'App Store',
    icon: (
      <Tile fill="url(#as)" grad={<G id="as" a="#4FC3FF" b="#1270F0" />}>
        <path d="M50 24 L30 68 M50 24 L70 68 M24 56 H76" stroke="#fff" strokeWidth="7" strokeLinecap="round" fill="none" />
      </Tile>
    ),
  },
  {
    name: 'System Settings',
    icon: (
      <Tile fill="url(#set)" grad={<G id="set" a="#A9ADB5" b="#6E737C" />}>
        <g transform="translate(50 50)">
          {Array.from({ length: 12 }, (_, i) => (
            <rect key={i} x="-4.5" y="-33" width="9" height="12" rx="2" fill="#E7E9EC" transform={`rotate(${i * 30})`} />
          ))}
          <circle r="24" fill="#E7E9EC" />
          <circle r="14" fill="#80858D" />
          <circle r="7" fill="#E7E9EC" />
        </g>
      </Tile>
    ),
  },
  {
    name: 'Dockorate',
    running: true,
    dockorate: true,
  },
];

export const DOCK_STACKS = [
  {
    name: 'Downloads',
    icon: (
      <svg viewBox="0 0 100 100" aria-hidden="true">
        <defs><G id="dl" a="#7CC4FF" b="#3A8EF0" /></defs>
        <path d="M10 28 a6 6 0 0 1 6 -6 h22 l6 7 h40 a6 6 0 0 1 6 6 v43 a6 6 0 0 1 -6 6 H16 a6 6 0 0 1 -6 -6 Z" fill="url(#dl)" />
      </svg>
    ),
  },
  {
    name: 'Trash',
    icon: (
      <svg viewBox="0 0 100 100" aria-hidden="true">
        <defs><G id="tr" a="#F2F4F7" b="#C9CED6" /></defs>
        <path d="M22 18 H78 L72 92 H28 Z" fill="url(#tr)" />
        <ellipse cx="50" cy="18" rx="28" ry="5" fill="#B5BBC4" />
      </svg>
    ),
  },
];

export function CalendarIcon() {
  return <Tile fill="#fff" />;
}
