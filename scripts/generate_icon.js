/**
 * SpendFlux icon generator — pure Node.js, no dependencies.
 *
 * Design:
 *   • 1024×1024 canvas
 *   • Teal-to-dark-teal gradient background with rounded corners
 *   • White "SF" monogram with a subtle upward-trending arrow integrated
 *     into the letterform
 *   • Small coral accent dot bottom-right
 *
 * Outputs a minimal valid PNG using raw deflate + PNG chunk encoding.
 */

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SIZE = 1024;

// ── Colour helpers ────────────────────────────────────────────────────────────

function hexToRgb(hex) {
  const n = parseInt(hex.replace('#', ''), 16);
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
}

// ── Pixel buffer ──────────────────────────────────────────────────────────────

// RGBA flat array
const pixels = new Uint8Array(SIZE * SIZE * 4);

function setPixel(x, y, r, g, b, a = 255) {
  if (x < 0 || x >= SIZE || y < 0 || y >= SIZE) return;
  const i = (y * SIZE + x) * 4;
  // Alpha-blend over existing pixel
  const srcA = a / 255;
  const dstA = pixels[i + 3] / 255;
  const outA = srcA + dstA * (1 - srcA);
  if (outA === 0) return;
  pixels[i]     = Math.round((r * srcA + pixels[i]     * dstA * (1 - srcA)) / outA);
  pixels[i + 1] = Math.round((g * srcA + pixels[i + 1] * dstA * (1 - srcA)) / outA);
  pixels[i + 2] = Math.round((b * srcA + pixels[i + 2] * dstA * (1 - srcA)) / outA);
  pixels[i + 3] = Math.round(outA * 255);
}

// Anti-aliased circle fill
function fillCircleAA(cx, cy, r, R, G, B, alpha = 255) {
  const x0 = Math.floor(cx - r - 1), x1 = Math.ceil(cx + r + 1);
  const y0 = Math.floor(cy - r - 1), y1 = Math.ceil(cy + r + 1);
  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      const dist = Math.sqrt((x - cx) ** 2 + (y - cy) ** 2);
      const coverage = Math.max(0, Math.min(1, r + 0.5 - dist));
      if (coverage > 0) setPixel(x, y, R, G, B, Math.round(alpha * coverage));
    }
  }
}

// Anti-aliased filled rectangle
function fillRect(x0, y0, w, h, R, G, B, alpha = 255) {
  for (let y = y0; y < y0 + h; y++) {
    for (let x = x0; x < x0 + w; x++) {
      setPixel(x, y, R, G, B, alpha);
    }
  }
}

// Thick anti-aliased line
function drawLineAA(x0, y0, x1, y1, thickness, R, G, B, alpha = 255) {
  const dx = x1 - x0, dy = y1 - y0;
  const len = Math.sqrt(dx * dx + dy * dy);
  const nx = -dy / len, ny = dx / len; // normal
  const steps = Math.ceil(len * 2);
  const half = thickness / 2;
  for (let s = 0; s <= steps; s++) {
    const t = s / steps;
    const cx = x0 + dx * t, cy = y0 + dy * t;
    for (let d = -half - 1; d <= half + 1; d++) {
      const px = Math.round(cx + nx * d);
      const py = Math.round(cy + ny * d);
      const coverage = Math.max(0, Math.min(1, half + 0.5 - Math.abs(d)));
      if (coverage > 0) setPixel(px, py, R, G, B, Math.round(alpha * coverage));
    }
  }
}

// ── Background: teal gradient rounded rect ────────────────────────────────────

const BG_TOP    = [0x4E, 0xCD, 0xC4]; // #4ECDC4
const BG_BOTTOM = [0x2D, 0x9E, 0x8F]; // #2D9E8F
const RADIUS = 220;

for (let y = 0; y < SIZE; y++) {
  const t = y / (SIZE - 1);
  const R = Math.round(BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t);
  const G = Math.round(BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t);
  const B = Math.round(BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t);

  for (let x = 0; x < SIZE; x++) {
    // Rounded-rect SDF
    const qx = Math.abs(x - SIZE / 2) - (SIZE / 2 - RADIUS);
    const qy = Math.abs(y - SIZE / 2) - (SIZE / 2 - RADIUS);
    const dist = Math.sqrt(Math.max(qx, 0) ** 2 + Math.max(qy, 0) ** 2) - RADIUS;
    const coverage = Math.max(0, Math.min(1, 0.5 - dist));
    if (coverage > 0) setPixel(x, y, R, G, B, Math.round(255 * coverage));
  }
}

// ── Subtle inner glow (lighter teal circle top-left) ─────────────────────────

for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    const dist = Math.sqrt((x - SIZE * 0.25) ** 2 + (y - SIZE * 0.2) ** 2);
    const glow = Math.max(0, 1 - dist / (SIZE * 0.45));
    if (glow > 0) {
      const i = (y * SIZE + x) * 4;
      if (pixels[i + 3] > 0) {
        pixels[i]     = Math.min(255, pixels[i]     + Math.round(40 * glow));
        pixels[i + 1] = Math.min(255, pixels[i + 1] + Math.round(30 * glow));
        pixels[i + 2] = Math.min(255, pixels[i + 2] + Math.round(20 * glow));
      }
    }
  }
}

// ── "S" letterform (white) ────────────────────────────────────────────────────
// Built from thick rounded strokes forming a stylised S

const W = 255; // white
const STROKE = 62;

// S: top arc  (top-left to top-right of upper half)
// We approximate arcs with polylines
function drawArc(cx, cy, rx, ry, startDeg, endDeg, thickness, R, G, B) {
  const steps = 120;
  let px = null, py = null;
  for (let i = 0; i <= steps; i++) {
    const angle = (startDeg + (endDeg - startDeg) * (i / steps)) * Math.PI / 180;
    const x = cx + rx * Math.cos(angle);
    const y = cy + ry * Math.sin(angle);
    if (px !== null) drawLineAA(px, py, x, y, thickness, R, G, B);
    px = x; py = y;
  }
}

// Upper bowl of S
drawArc(512, 330, 155, 130, 200, 360 + 20, STROKE, W, W, W);
// Lower bowl of S
drawArc(512, 694, 155, 130, 20, 200, STROKE, W, W, W);
// Middle connector
drawLineAA(357, 330, 667, 694, STROKE, W, W, W);

// ── Upward-trending arrow (coral accent) ─────────────────────────────────────

const CORAL = [0xFF, 0x6B, 0x6B];
const AX = 680, AY = 680; // arrow tip
const ASTROKE = 44;

// Arrow shaft
drawLineAA(AX - 90, AY + 90, AX, AY, ASTROKE, ...CORAL);
// Arrow head left wing
drawLineAA(AX, AY, AX - 60, AY, ASTROKE - 10, ...CORAL);
// Arrow head bottom wing
drawLineAA(AX, AY, AX, AY + 60, ASTROKE - 10, ...CORAL);

// ── Coral accent dot bottom-right ────────────────────────────────────────────

fillCircleAA(760, 760, 52, ...CORAL);

// ── PNG encoder ───────────────────────────────────────────────────────────────

function crc32(buf) {
  const table = (() => {
    const t = new Uint32Array(256);
    for (let i = 0; i < 256; i++) {
      let c = i;
      for (let j = 0; j < 8; j++) c = (c & 1) ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[i] = c;
    }
    return t;
  })();
  let crc = 0xffffffff;
  for (const b of buf) crc = table[(crc ^ b) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBytes = Buffer.from(type, 'ascii');
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const crcInput = Buffer.concat([typeBytes, data]);
  const crcBuf = Buffer.alloc(4); crcBuf.writeUInt32BE(crc32(crcInput));
  return Buffer.concat([len, typeBytes, data, crcBuf]);
}

function encodePNG(pixels, width, height) {
  // IHDR
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 2;  // colour type: RGB  — we'll use RGBA (6)
  ihdr[9] = 6;
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;

  // Raw image data with filter byte per row
  const raw = Buffer.alloc(height * (1 + width * 4));
  for (let y = 0; y < height; y++) {
    raw[y * (1 + width * 4)] = 0; // filter: None
    for (let x = 0; x < width; x++) {
      const src = (y * width + x) * 4;
      const dst = y * (1 + width * 4) + 1 + x * 4;
      raw[dst]     = pixels[src];
      raw[dst + 1] = pixels[src + 1];
      raw[dst + 2] = pixels[src + 2];
      raw[dst + 3] = pixels[src + 3];
    }
  }

  const compressed = zlib.deflateSync(raw, { level: 6 });

  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', compressed),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ── Write output ──────────────────────────────────────────────────────────────

const outDir = path.join(__dirname, '..', 'assets', 'icons');
fs.mkdirSync(outDir, { recursive: true });

const pngData = encodePNG(pixels, SIZE, SIZE);
const outPath = path.join(outDir, 'app_icon.png');
fs.writeFileSync(outPath, pngData);
console.log(`Written ${outPath} (${(pngData.length / 1024).toFixed(1)} KB)`);
