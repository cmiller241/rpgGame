// spriteShadow.js
//
// Shadows cast by sprites (trees, crops, pages, the player).
//
// Sprites call spriteShadow.add(caster) while the scene is being built.
// Then:
//   * spriteShadow.flush() draws every caster's shadow onto canvas.shadow
//     for the terrain to receive. Casters that share a sprite sheet go out
//     in ONE draw call: each caster becomes a rectangle in a single mesh,
//     with that caster's details stored on its vertices (see
//     spriteShadowShader.glsl).
//   * spriteShadow.sunShadowAt() answers the same question on the CPU for
//     a single point, so sprites standing in another sprite's shadow (e.g.
//     the player under a tree) can be darkened.
//
// The list is cleared at the start of each frame with spriteShadow.clear().

import love from '../love/index.js';
import canvas from './canvas.js';
import shader from './shader.js';
import terrain from './terrain.js';
import window from './window.js';

const spriteShadow = {};
export default spriteShadow;

const casters = [];
let count = 0;

// Longest shadow (px) we'll draw a rectangle for.
const MAX_SHADOW_LENGTH = 600;

spriteShadow.clear = function () {
  casters.length = 0;
  count = 0;
};

// Queue a caster. Fields:
//   image        Image or Canvas the sprite lives in
//   data         (optional) ImageData copy of `image`, needed for sunShadowAt
//   quadX, quadY, quadW, quadH   sprite rectangle within that image (px)
//   anchorX, anchorY             px inside the quad where it touches the ground
//   worldX, worldY, worldZ       world position + ground height of the anchor
//   lift         (optional) px raised off the ground, e.g. jumping
//   opacity      (optional) 0..1 sun-shadow strength, default 1
//   castLamp     (optional) true to also block the player's lamp
//   swayPx, swayAnchor  (optional) wind sway: px shift at the sprite's top,
//                and where the bend starts (fraction down the quad)
spriteShadow.add = function (c) {
  casters[count] = c;
  count = count + 1;
};

// ---------------------------------------------------------------------------
// GPU: draw all shadows onto canvas.shadow
// ---------------------------------------------------------------------------

// Screen-space rectangle [x0, y0, x1, y1] that contains every pixel this
// caster's shadow could touch, or null if it's entirely off screen.
function shadowBounds(c, sunState, lamp, cameraX, cameraY) {
  // How far the sprite (plus sway) reaches sideways from its anchor.
  const halfWidth = Math.max(c.anchorX, c.quadW - c.anchorX) + Math.abs(c.swayPx || 0);
  const spriteTop = c.anchorY + (c.lift || 0);  // tallest point above the ground

  // The sprite stands on a horizontal base line through its feet
  // (worldX +- halfWidth, at worldY), see spriteShadowShader.glsl.
  let minX = c.worldX - halfWidth, maxX = c.worldX + halfWidth;
  let minY = c.worldY - 1, maxY = c.worldY + 1;
  let any = false;

  if (sunState.isUp && sunState.litLevel > sunState.shadowLevel) {
    // The sun is always on the camera side (dirY > 0), so the shadow runs
    // from the base line away from the sun and never below the feet.
    // Worst case it falls onto the lowest ground on the map (the floor
    // of the deepest pit), so project the sprite's full height above that.
    const length = Math.min((spriteTop + c.worldZ - terrain.minHeight) / sunState.slope, MAX_SHADOW_LENGTH);
    const tipX = c.worldX - sunState.dirX * length;
    const tipY = c.worldY - sunState.dirY * length;
    // Soft edges spread up to (distance * softness) px past the silhouette.
    const blur = length * sunState.softness + 1;
    minX = Math.min(minX, tipX - halfWidth - blur);
    maxX = Math.max(maxX, tipX + halfWidth + blur);
    minY = Math.min(minY, tipY - blur);
    any = true;
  }

  if (c.castLamp) {
    const dx = c.worldX - lamp.x, dy = c.worldY - lamp.y;
    if (dx * dx + dy * dy < (lamp.radius + halfWidth) ** 2) {
      minX = Math.min(minX, lamp.x - lamp.radius);
      maxX = Math.max(maxX, lamp.x + lamp.radius);
      minY = Math.min(minY, lamp.y - lamp.radius);
      maxY = Math.max(maxY, lamp.y + lamp.radius);
      any = true;
    }
  }

  if (!any) return null;

  // World ground-plane box -> screen box. Terrain at height h is drawn h px
  // higher, so extend the top by the tallest terrain on the map and the
  // bottom by the deepest pit.
  const x0 = Math.max(0, Math.floor(minX - cameraX));
  const x1 = Math.min(window.width, Math.ceil(maxX - cameraX));
  const y0 = Math.max(0, Math.floor(minY - cameraY - terrain.maxHeight));
  const y1 = Math.min(window.height, Math.ceil(maxY - cameraY - terrain.minHeight));
  if (x1 <= x0 || y1 <= y0) return null;
  return [x0, y0, x1, y1];
}

// Mesh of rectangles, one per caster. Each vertex carries its caster's
// details as extra attributes (names must match spriteShadowShader.glsl).
const VERTEX_FORMAT = [
  ['VertexPosition',   'float', 2],
  ['CasterQuad',       'float', 4],   // quad x, y, w, h in the image (px)
  ['CasterAnchorLift', 'float', 4],   // anchor x, anchor y, lift, sun-shadow opacity
  ['CasterBase',       'float', 4],   // world x, y, height of the anchor; castLamp (0/1)
  ['CasterSway',       'float', 2],   // sway px at the top, bend start (fraction down)
];
let mesh = null, meshCapacity = 0;
const vertices = [];

function ensureCapacity(n) {
  if (n <= meshCapacity) return;
  meshCapacity = Math.max(n, meshCapacity * 2, 600);
  if (mesh) mesh.release();
  mesh = love.graphics.newMesh(VERTEX_FORMAT, meshCapacity, 'triangles', 'stream');
}

// Writes the 6 vertices (two triangles) of one caster's rectangle, starting
// at vertex n; returns the next free vertex.
function pushRect(n, c, x0, y0, x1, y1) {
  const quadX = c.quadX, quadY = c.quadY, quadW = c.quadW, quadH = c.quadH;
  const ax = c.anchorX, ay = c.anchorY, lift = c.lift || 0, op = c.opacity ?? 1;
  const bx = c.worldX, by = c.worldY, bz = c.worldZ, lamp = c.castLamp ? 1 : 0;
  const sw = c.swayPx || 0, sa = c.swayAnchor || 1;
  const corners = [x0, y0, x1, y0, x0, y1, x1, y0, x1, y1, x0, y1];
  for (let i = 0; i < 6; i++) {
    let v = vertices[n + i];
    if (!v) { v = []; vertices[n + i] = v; }
    v[0] = corners[i * 2]; v[1] = corners[i * 2 + 1];
    v[2] = quadX; v[3] = quadY; v[4] = quadW; v[5] = quadH;
    v[6] = ax; v[7] = ay; v[8] = lift; v[9] = op;
    v[10] = bx; v[11] = by; v[12] = bz; v[13] = lamp;
    v[14] = sw; v[15] = sa;
  }
  return n + 6;
}

// Renders every queued shadow into canvas.shadow: one draw call per sprite sheet.
spriteShadow.flush = function (sunState, lamp, cameraX, cameraY) {
  if (count === 0) return;

  // Group casters by image, building one vertex list with a range per image.
  const groups = new Map();
  for (let i = 0; i < count; i++) {
    const c = casters[i];
    let g = groups.get(c.image);
    if (!g) { g = []; groups.set(c.image, g); }
    g.push(c);
  }

  let n = 0;
  const ranges = [];
  for (const [image, group] of groups) {
    const first = n;
    for (const c of group) {
      const b = shadowBounds(c, sunState, lamp, cameraX, cameraY);
      if (b) n = pushRect(n, c, b[0], b[1], b[2], b[3]);
    }
    if (n > first) ranges.push([image, first, n - first]);
  }
  if (n === 0) return;

  ensureCapacity(n);
  // Only this frame's vertices are uploaded.
  mesh.setVertices(vertices, 0, n);

  const s = shader.spriteShadow;
  love.graphics.setCanvas(canvas.shadow);
  love.graphics.setShader(s);
  love.graphics.setBlendMode('lighten', 'premultiplied');
  love.graphics.setColor(1, 1, 1, 1);

  terrain.sendUniforms(s, cameraX, cameraY);
  s.send('sunUp', sunState.isUp ? 1 : 0);
  s.send('sunDir', [sunState.dirX, sunState.dirY]);
  s.send('sunSlope', sunState.slope);
  s.send('sunSoftness', sunState.softness);
  s.send('lampPos', [lamp.x, lamp.y, lamp.z]);
  s.send('lampRadius', lamp.radius);

  for (const [image, first, len] of ranges) {
    s.send('casterImage', image);
    s.send('casterImageSize', image.getDimensions());
    mesh.setDrawRange(first, len);   // (0-based first vertex here)
    love.graphics.draw(mesh);
  }
  mesh.setDrawRange();

  love.graphics.setBlendMode('alpha');
  love.graphics.setShader();
};

// ---------------------------------------------------------------------------
// CPU: is a single point in a sprite's sun shadow?
// ---------------------------------------------------------------------------

// 0..1: how strongly any queued caster (other than `exclude`) blocks the sun
// for world point (wx, wy) at height h. Mirrors hitsBillboard() in
// spriteShadowShader.glsl with a single sample (no soft edge). Casters
// without CPU image data (the player) are skipped.
spriteShadow.sunShadowAt = function (wx, wy, h, exclude, sunState) {
  if (!sunState.isUp || Math.abs(sunState.dirY) < 0.001) return 0;
  let best = 0;
  for (let i = 0; i < count; i++) {
    const c = casters[i];
    if (c !== exclude && c.data) {
      const t = (c.worldY - wy) / sunState.dirY;        // distance to the billboard plane
      if (t > 0) {
        const lateral = wx + sunState.dirX * t - c.worldX;
        const heightAbove = h + t * sunState.slope - c.worldZ - (c.lift || 0);
        let px = c.anchorX + lateral;
        const py = c.anchorY - heightAbove;
        if (py >= 0 && py < c.quadH) {
          // Same wind bend as the canopy (see windSwayShader.glsl).
          if (c.swayPx) {
            const bend = Math.max(0, Math.min(1, (c.swayAnchor - py / c.quadH) / c.swayAnchor));
            px = px - c.swayPx * bend * bend;
          }
          if (px >= 0 && px < c.quadW) {
            const a = c.data.getPixel(c.quadX + Math.floor(px), c.quadY + Math.floor(py))[3];
            if (a > 0.5) {
              best = Math.max(best, c.opacity ?? 1);
              if (best >= 1) return 1;
            }
          }
        }
      }
    }
  }
  return best;
};
