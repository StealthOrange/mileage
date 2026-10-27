/* Local illustration for the simulated preview. Not a recorded GPS map. */
(function () {
  'use strict';

  const route = [
    [[95, 130], [108, 132], [124, 140], [136, 143]],
    [[136, 143], [147, 130], [158, 130], [162, 144]],
    [[162, 144], [162, 159], [174, 164], [185, 172]],
    [[185, 172], [200, 182], [195, 192], [201, 197]],
    [[201, 197], [207, 202], [216, 192], [224, 203]],
    [[224, 203], [239, 218], [256, 234], [269, 237]],
    [[269, 237], [287, 244], [284, 223], [297, 230]],
    [[297, 230], [306, 235], [313, 240], [320, 245]]
  ];
  const routePath = 'M95 130 ' + route.map(curve => 'C' + curve.slice(1).map(p => p.join(' ')).join(' ')).join(' ');
  const samples = [];
  for (const curve of route) {
    for (let i = 0; i <= 24; i++) {
      const t = i / 24, u = 1 - t;
      samples.push([
        u * u * u * curve[0][0] + 3 * u * u * t * curve[1][0] + 3 * u * t * t * curve[2][0] + t * t * t * curve[3][0],
        u * u * u * curve[0][1] + 3 * u * u * t * curve[1][1] + 3 * u * t * t * curve[2][1] + t * t * t * curve[3][1]
      ]);
    }
  }
  const lengths = [0];
  for (let i = 1; i < samples.length; i++) {
    lengths.push(lengths[i - 1] + Math.hypot(samples[i][0] - samples[i - 1][0], samples[i][1] - samples[i - 1][1]));
  }
  function routePoint(progress) {
    const distance = lengths[lengths.length - 1] * progress;
    const index = lengths.findIndex(length => length >= distance);
    if (index <= 0) return samples[0];
    const fraction = (distance - lengths[index - 1]) / Math.max(.001, lengths[index] - lengths[index - 1]);
    return samples[index - 1].map((value, axis) => value + fraction * (samples[index][axis] - value));
  }

  // Neighborhoods have their own angles and offsets, avoiding a schematic square grid.
  function streets(cx, cy, width, height, spacing, angle, seed) {
    const paths = [];
    const jitter = n => Math.sin((n + seed) * 17.13) * 1.35;
    for (let x = -width / 2; x <= width / 2; x += spacing) {
      const j = jitter(x);
      paths.push(`<path d="M${(x + j).toFixed(1)} ${-height / 2}l${(j * .5).toFixed(1)} ${(height * .48).toFixed(1)}l${(-j * .8).toFixed(1)} ${(height * .52).toFixed(1)}"/>`);
    }
    for (let y = -height / 2; y <= height / 2; y += spacing * .8) {
      const j = jitter(y + 5);
      paths.push(`<path d="M${-width / 2} ${(y + j).toFixed(1)}l${(width * .45).toFixed(1)} ${(j * .5).toFixed(1)}l${(width * .55).toFixed(1)} ${(-j * .4).toFixed(1)}"/>`);
    }
    return `<g transform="translate(${cx} ${cy}) rotate(${angle})">${paths.join('')}</g>`;
  }

  const minorStreets = [
    streets(76, 87, 178, 152, 8.5, 9, 3),
    streets(214, 77, 128, 158, 7.7, -4, 9),
    streets(337, 87, 135, 168, 9, 4, 15),
    streets(67, 238, 155, 144, 9, 26, 22),
    streets(199, 234, 119, 190, 7.2, -11, 33),
    streets(312, 243, 129, 173, 8, 11, 42)
  ].join('');

  const arterials = [
    'M-12 102C68 114 122 112 166 115S276 108 411 120',
    'M-10 185C70 177 120 186 170 181S281 179 414 187',
    'M-5 257C70 242 112 248 178 249S302 261 412 250',
    'M65-12C60 48 70 80 68 132S57 233 47 334',
    'M144-10C133 52 143 100 142 142S127 243 112 330',
    'M271-10C260 60 271 93 262 148S255 242 265 330',
    'M351-8C348 46 337 93 344 147S361 247 350 331',
    'M-9 303C77 246 115 214 172 177S294 93 413 41',
    'M-12 27C60 72 105 95 160 134S273 230 412 320'
  ];
  const highways = [
    'M-12 154C54 155 96 154 137 156C179 159 188 149 220 153C259 157 306 159 412 161',
    'M199-12C197 30 198 58 200 91C200 121 218 139 219 165C221 205 253 222 286 253L360 332',
    'M72 71C103 41 164 41 225 44C282 45 322 65 328 103L334 225C336 270 298 290 229 287L112 278C73 275 60 254 62 219L63 119C63 99 65 82 72 71Z',
    'M-8 314C44 279 67 264 100 236C133 209 159 194 189 178C206 170 216 166 236 163'
  ];

  function shield(x, y, number) {
    const width = number.length === 3 ? 20 : 17;
    return `<g transform="translate(${x} ${y})" aria-hidden="true"><path d="M${-width / 2} -9Q0 -5 ${width / 2} -9V1Q${width / 2 - 1} 7 0 11Q${-width / 2 + 1} 7 ${-width / 2} 1Z" fill="var(--color-surface-secondary)" stroke="var(--color-text-secondary)" stroke-width=".9"/><path d="M${-width / 2 + 1} -5H${width / 2 - 1}" stroke="var(--color-text-secondary)" stroke-width=".6"/><text y="4" fill="var(--color-text)" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="8" font-weight="600" text-anchor="middle">${number}</text></g>`;
  }

  window.mileageMapMarkup = function ({ showRoute = true, progress = 1, compact = false } = {}) {
    const fraction = Math.max(0, Math.min(1, Number.isFinite(Number(progress)) ? Number(progress) : 1));
    const endpoint = routePoint(fraction);
    return `<svg viewBox="0 0 400 320" preserveAspectRatio="xMidYMid slice" role="img" aria-label="Illustrative Houston preview map" xmlns="http://www.w3.org/2000/svg" class="houston-map${compact ? ' compact' : ''}">
      <title>Illustrative Houston preview map</title>
      <rect width="400" height="320" fill="var(--color-background)"/>
      <g fill="color-mix(in srgb,var(--color-accent) 5%,var(--color-background))" stroke="none">
        <path d="M28 75L65 77 58 107 39 118 21 96Z"/><path d="M110 148L145 147 149 172 123 181 108 164Z"/>
        <path d="M202 236L231 244 226 277 206 284 194 269Z"/><path d="M306 54L326 63 322 92 303 90Z"/>
        <path d="M10 264L35 257 49 280 36 307 13 300Z"/>
      </g>
      <g fill="color-mix(in srgb,var(--color-text-secondary) 8%,var(--color-background))">
        <path d="M354-5L400-5 400 320 362 320 358 300 370 281 350 270 365 247 350 228 358 207 343 184 357 162 346 140 358 124 346 102 360 83 349 64 363 42Z"/>
        <path d="M-10 121C39 112 67 130 100 121S145 89 174 100S207 132 245 122S302 128 341 117S384 103 415 111" fill="none" stroke="color-mix(in srgb,var(--color-text-secondary) 17%,var(--color-background))" stroke-width="4"/>
        <path d="M268 171C281 192 281 205 300 214S321 238 348 244S375 267 406 270" fill="none" stroke="color-mix(in srgb,var(--color-text-secondary) 15%,var(--color-background))" stroke-width="3"/>
        <path d="M340 24l13 5-4 13-13-2ZM365 76l13-3 2 15-12 2ZM345 133l9-4 7 10-9 7ZM378 179l17 2-1 14-19-3ZM339 225l14-7 5 13-13 9ZM368 282l13 1 1 17-17-5Z"/>
      </g>
      <g fill="none" stroke="var(--color-border)" stroke-width=".48" opacity=".82">${minorStreets}</g>
      <g fill="none" stroke="var(--color-text-secondary)" stroke-width=".8" opacity=".25">${arterials.map(d => `<path d="${d}"/>`).join('')}</g>
      <g fill="none" stroke="var(--color-background)" stroke-width="5" opacity=".9">${highways.map(d => `<path d="${d}"/>`).join('')}</g>
      <g fill="none" stroke="var(--color-text-secondary)" stroke-width="1.7" opacity=".48">${highways.map(d => `<path d="${d}"/>`).join('')}</g>
      <g fill="none" stroke="var(--color-border)" stroke-width=".6" opacity=".9"><path d="M207 134l21-6 14 15-6 22-23 5-17-13Z"/><path d="M212 137l5 28m-12-23 27 8m-25 8 24-16"/></g>
      <g font-family="-apple-system,BlinkMacSystemFont,sans-serif" fill="var(--color-text-secondary)" font-size="6.3" opacity=".65" text-anchor="middle" aria-hidden="true"><text x="111" y="70">HEIGHTS</text><text x="105" y="218">RIVER OAKS</text><text x="286" y="104">FIFTH WARD</text><text x="282" y="286">SOUTH HOUSTON</text></g>
      ${shield(30, 155, '10')}${shield(204, 59, '45')}${shield(325, 160, '610')}
      <text x="236" y="171" fill="var(--color-text)" stroke="var(--color-background)" stroke-width="3" paint-order="stroke" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="17" font-weight="500" letter-spacing=".2" text-anchor="middle">Houston</text>
      ${showRoute ? `<path d="${routePath}" fill="none" stroke="var(--color-background)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" pathLength="100" stroke-dasharray="100" stroke-dashoffset="${100 * (1 - fraction)}"/><path d="${routePath}" fill="none" stroke="var(--color-accent)" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round" pathLength="100" stroke-dasharray="100" stroke-dashoffset="${100 * (1 - fraction)}"/><circle cx="95" cy="130" r="6.6" fill="var(--color-background)" stroke="var(--color-text)" stroke-width="2.2"/><circle cx="${endpoint[0].toFixed(2)}" cy="${endpoint[1].toFixed(2)}" r="7.1" fill="var(--color-accent)" stroke="var(--color-background)" stroke-width="2.8"/><circle cx="${endpoint[0].toFixed(2)}" cy="${endpoint[1].toFixed(2)}" r="3.5" fill="var(--color-accent)" stroke="#36560A" stroke-width=".8"/>` : ''}
    </svg>`;
  };
}());
