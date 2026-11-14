// render.js
//
// Draws the map into a 2D canvas, in two views:
//
//   FLAT    top-down data view: every tile at its grid position, with
//           height colours/numbers, water, block markers and objects.
//   HEIGHT  the game's 3/4 view: tiles lifted by their height, cliff faces,
//           pit walls, floating blocks, water, and trees/crops/pages drawn
//           up from their base, using the game's own art.
//
// The HEIGHT view copies the game's drawing rules (grass.lua, dirt.lua,
// mountain.lua, crop.lua, tree.lua, main.lua) so it looks like the game,
// minus lighting. If those rules change in the game, update them here too.

(function (root) {
    "use strict";

    const TS = 32;

    // Tile types (see src/tiles.lua in the game).
    const TILE_TYPES = [
        { id: 1,   name: "Grass" },
        { id: 10,  name: "Tall grass" },
        { id: 56,  name: "Plowed dirt" },
        { id: 72,  name: "Seeds (dry)" },   { id: 73, name: "Seeds (watered)" },
        { id: 74,  name: "Sprout (dry)" },  { id: 75, name: "Sprout (watered)" },
        { id: 76,  name: "Crop 3 (dry)" },  { id: 77, name: "Crop 3 (watered)" },
        { id: 78,  name: "Crop 4 (dry)" },  { id: 79, name: "Crop 4 (watered)" },
        { id: 80,  name: "Crop 5 (dry)" },  { id: 81, name: "Crop 5 (watered)" },
        { id: 82,  name: "Crop 6 (dry)" },  { id: 83, name: "Crop 6 (watered)" },
        { id: 84,  name: "Crop 7 (dry)" },  { id: 85, name: "Crop 7 (watered)" },
        { id: 86,  name: "Grown (dry)" },   { id: 87, name: "Grown (watered)" },
        { id: 512, name: "Oak tree" },
        { id: 520, name: "Pine tree" },
    ];
    const typeName = (id) => (TILE_TYPES.find(t => t.id === id) || { name: "Unknown (" + id + ")" }).name;
    const isCrop = (t) => t >= 72 && t <= 87;
    const isDirt = (t) => t === 56 || isCrop(t);
    const isTree = (t) => t === 512 || t === 520;

    // Trees: which part of img/tree4.png, and where the trunk base is inside
    // that 480x480 quad. The base sits 16 px across and 26 px down the tile.
    const TREES = {
        512: { sx: 0,   anchorX: 240, anchorY: 250 },
        520: { sx: 960, anchorX: 244, anchorY: 258 },
    };
    const TREE_BASE_X = 16, TREE_BASE_Y = 26;

    // ------------------------------------------------------------------
    // Map queries (0-based col/row)
    // ------------------------------------------------------------------

    function inMap(m, c, r) { return r >= 0 && r < m.height && c >= 0 && c < m.width; }
    function heightAt(m, c, r) { return inMap(m, c, r) ? m.heights[r][c] : 0; }

    // Bottom of tile (c, r)'s south wall: the lower of ground level and the
    // tile in front of it (terrain:faceBottom).
    function faceBottom(m, c, r) { return Math.min(0, heightAt(m, c, r + 1)); }

    // ------------------------------------------------------------------
    // Slopes (the same model as the game's terrain.lua, SLOPES)
    //
    // Neighbouring tiles whose heights differ by less than SLOPE_LIMIT are
    // "joined": instead of a little cliff between them, the ground slants
    // smoothly from one to the other. Bigger differences stay cliffs.
    //
    // Each tile still has one height in the map. What gets drawn is a top
    // surface through five points, k = [nw, ne, sw, se, centre]:
    //   * corners: a corner is shared by up to four tiles; they're grouped
    //     by joined edges (N-S and E-W neighbours, not diagonals), and every
    //     tile in a group uses the group's average height there, so joined
    //     tiles meet without seams
    //   * centre: the tile's own height, so a lone raised tile still peaks
    //     at the height it was given
    // Inside a tile the surface is four bilinear quarters through the
    // corners, the edge midpoints and the centre (edgeHeights).
    // ------------------------------------------------------------------

    const SLOPE_LIMIT = 32;
    let slopesOn = true;     // set from opts.slopes on each height-view draw

    function joined(a, b) { return slopesOn && Math.abs(a - b) < SLOPE_LIMIT; }

    // Height of grid point (gx, gy) (the corner between tiles gx-1..gx and
    // gy-1..gy) as seen from tile (c, r), one of those four tiles: the
    // average height of the tiles in its group there.
    function cornerFor(m, c, r, gx, gy) {
        if (!slopesOn) return heightAt(m, c, r);
        // 0 = NW tile, 1 = NE, 2 = SW, 3 = SE of the grid point
        const cs = [gx - 1, gx, gx - 1, gx], rs = [gy - 1, gy - 1, gy, gy];
        const hs = [], parent = [0, 1, 2, 3];
        for (let i = 0; i < 4; i++) hs.push(inMap(m, cs[i], rs[i]) ? m.heights[rs[i]][cs[i]] : null);
        const find = i => (parent[i] === i ? i : (parent[i] = find(parent[i])));
        for (const [a, b] of [[0, 1], [2, 3], [0, 2], [1, 3]]) {
            if (hs[a] !== null && hs[b] !== null && joined(hs[a], hs[b])) parent[find(a)] = find(b);
        }
        const self = (c === gx - 1 ? 0 : 1) + (r === gy - 1 ? 0 : 2);
        let sum = 0, n = 0;
        for (let i = 0; i < 4; i++) if (hs[i] !== null && find(i) === find(self)) { sum += hs[i]; n++; }
        return sum / n;
    }

    // Surface points of tile (c, r): [nw, ne, sw, se, centre].
    function corners(m, c, r) {
        return [cornerFor(m, c, r, c, r), cornerFor(m, c, r, c + 1, r),
                cornerFor(m, c, r, c, r + 1), cornerFor(m, c, r, c + 1, r + 1), heightAt(m, c, r)];
    }
    const isFlat = k => k[0] === k[4] && k[1] === k[4] && k[2] === k[4] && k[3] === k[4];

    // Heights along the north edge, middle line and south edge at fx (0..1).
    function edgeHeights(k, fx) {
        const n = k[0] + (k[1] - k[0]) * fx, s = k[2] + (k[3] - k[2]) * fx;
        const w = (k[0] + k[2]) / 2, e = (k[1] + k[3]) / 2;
        const mid = fx < 0.5 ? w + (k[4] - w) * fx * 2 : k[4] + (e - k[4]) * (fx * 2 - 1);
        return [n, mid, s];
    }

    function heightInTile(k, fx, fy) {
        if (isFlat(k)) return k[0];
        const [n, mid, s] = edgeHeights(k, fx);
        return fy < 0.5 ? n + (mid - n) * fy * 2 : mid + (s - mid) * (fy * 2 - 1);
    }

    // Ground height at world point (wx, wy).
    function surfaceAt(m, wx, wy) {
        const c = Math.floor(wx / TS), r = Math.floor(wy / TS);
        if (!inMap(m, c, r)) return 0;
        const fx = Math.min(1, Math.max(0, wx / TS - c)), fy = Math.min(1, Math.max(0, wy / TS - r));
        return heightInTile(corners(m, c, r), fx, fy);
    }

    // ------------------------------------------------------------------
    // Sprite helpers
    // ------------------------------------------------------------------

    // img/sprites2.png is a grid of 32 px tiles, 11 per row, numbered from 1.
    function drawQuad(ctx, img, n, x, y, scaleY) {
        const cols = Math.floor(img.width / TS);
        const sx = ((n - 1) % cols) * TS, sy = Math.floor((n - 1) / cols) * TS;
        ctx.drawImage(img, sx, sy, TS, TS, x, y, TS, TS * (scaleY || 1));
    }

    // Draws tile sprite n warped onto a sloped top with surface points k;
    // (x, y) is the tile's ground-level position. In this view height only
    // moves things up the screen, never sideways, so the warp is exact as 32
    // one-pixel columns, each stretched from its north edge through its
    // middle line to its south edge (two halves where the middle bends).
    function drawQuadWarp(ctx, img, n, x, y, k) {
        const cols = Math.floor(img.width / TS);
        const sx = ((n - 1) % cols) * TS, sy = Math.floor((n - 1) / cols) * TS;
        for (let u = 0; u < TS; u++) {
            const [hn, hm, hs] = edgeHeights(k, (u + 0.5) / TS);
            const top = y - Math.round(hn), mid = y + TS / 2 - Math.round(hm), bottom = y + TS - Math.round(hs);
            if (Math.abs((mid - top) - (bottom - mid)) < 0.5) {
                if (bottom > top) ctx.drawImage(img, sx + u, sy, 1, TS, x + u, top, 1, bottom - top);
            } else {
                if (mid > top) ctx.drawImage(img, sx + u, sy, 1, TS / 2, x + u, top, 1, mid - top);
                if (bottom > mid) ctx.drawImage(img, sx + u, sy + TS / 2, 1, TS / 2, x + u, mid, 1, bottom - mid);
            }
        }
    }

    // Draws a tile layer flat or warped, whichever the surface needs.
    function drawTop(ctx, img, n, x, y, k) {
        if (isFlat(k)) drawQuad(ctx, img, n, x, y - k[0]);
        else drawQuadWarp(ctx, img, n, x, y, k);
    }

    // Light / shade on sloped ground: a fixed light from the upper left
    // (north-west, above), relative to flat ground (0 = flat, + = lit,
    // - = shaded). The slope is measured at 3x3 points per tile (corners,
    // edge midpoints, centre) by central differences that ignore samples
    // across a cliff edge (like terrain:slopeAt in the game), and blended
    // between them, so a hill shades smoothly.
    const LIGHT = (() => { const v = [-0.55, -0.55, 1]; const l = Math.hypot(...v); return v.map(a => a / l); })();
    const SLOPE_SAMPLE = 8;

    function lightAt(m, c, r, k, fx, fy) {
        const wx = (c + fx) * TS, wy = (r + fy) * TS;
        const h0 = heightInTile(k, fx, fy);
        const sample = (dx, dy) => {
            const sx = fx + dx / TS, sy = fy + dy / TS;
            return (sx >= 0 && sx <= 1 && sy >= 0 && sy <= 1) ? heightInTile(k, sx, sy) : surfaceAt(m, wx + dx, wy + dy);
        };
        const diff = (dx, dy) => {
            const hp = sample(dx, dy), hm = sample(-dx, -dy);
            const okP = Math.abs(hp - h0) < SLOPE_SAMPLE * 1.5, okM = Math.abs(h0 - hm) < SLOPE_SAMPLE * 1.5;
            if (okP && okM) return (hp - hm) / (2 * SLOPE_SAMPLE);
            if (okP) return (hp - h0) / SLOPE_SAMPLE;
            if (okM) return (h0 - hm) / SLOPE_SAMPLE;
            return 0;
        };
        const dhdx = diff(SLOPE_SAMPLE, 0), dhdy = diff(0, SLOPE_SAMPLE);
        const len = Math.hypot(dhdx, dhdy, 1);
        return (-dhdx * LIGHT[0] - dhdy * LIGHT[1] + LIGHT[2]) / len - LIGHT[2];
    }

    // Light value -> overlay colour.
    function shadeColour(l) {
        return l > 0 ? "rgba(255, 246, 215, " + Math.min(0.22, l * 0.9).toFixed(3) + ")"
                     : "rgba(12, 22, 44, " + Math.min(0.45, -l * 1.4).toFixed(3) + ")";
    }

    // Does tile (c, r) or a neighbour slope? (Others need no shading.)
    function nearSlope(m, c, r) {
        for (let rr = r - 1; rr <= r + 1; rr++) for (let cc = c - 1; cc <= c + 1; cc++) {
            if (inMap(m, cc, rr) && !isFlat(corners(m, cc, rr))) return true;
        }
        return false;
    }

    const SHADE_STEP = 2;   // px per shading column
    function shadeSlope(ctx, m, c, r, x, y, k) {
        if (!slopesOn || !nearSlope(m, c, r)) return;
        // Light at the 3x3 points: L[j][i], i = west/middle/east, j = north/middle/south.
        const L = [0, 1, 2].map(j => [0, 1, 2].map(i => lightAt(m, c, r, k, i / 2, j / 2)));
        if (Math.max(...L.flat().map(Math.abs)) < 0.01) return;
        const across = (row, f) => f < 0.5 ? row[0] + (row[1] - row[0]) * f * 2 : row[1] + (row[2] - row[1]) * (f * 2 - 1);
        for (let u = 0; u < TS; u += SHADE_STEP) {
            const f = (u + SHADE_STEP / 2) / TS;
            const [hn, hm, hs] = edgeHeights(k, f);
            const top = y - Math.round(hn), mid = y + TS / 2 - Math.round(hm), bottom = y + TS - Math.round(hs);
            const ln = across(L[0], f), lm = across(L[1], f), ls = across(L[2], f);
            for (const [y0, y1, a, b] of [[top, mid, ln, lm], [mid, bottom, lm, ls]]) {
                if (y1 <= y0) continue;
                if (Math.abs(a - b) < 0.005) {
                    ctx.fillStyle = shadeColour(a);
                } else {
                    const g = ctx.createLinearGradient(0, y0, 0, y1);
                    g.addColorStop(0, shadeColour(a));
                    g.addColorStop(1, shadeColour(b));
                    ctx.fillStyle = g;
                }
                ctx.fillRect(x + u, y0, SHADE_STEP, y1 - y0);
            }
        }
    }

    // Grass top (grass.lua): +1 if the tile above is not lower, +2 right, +4 left.
    // A lower neighbour joined by a slope isn't a drop, so it gets no edge.
    function grassQuad(m, c, r) {
        const h = heightAt(m, c, r);
        const noDrop = (cc, rr) => { const n = heightAt(m, cc, rr); return n >= h || joined(h, n); };
        let q = 1;
        if (r > 0 && noDrop(c, r - 1)) q += 1;
        if (c < m.width - 1 && noDrop(c + 1, r)) q += 2;
        if (c > 0 && noDrop(c - 1, r)) q += 4;
        return q;
    }

    // Dirt (dirt.lua): 56 + up 1 / left 2 / right 4 / down 8 for dirt neighbours.
    function dirtQuad(m, c, r) {
        const d = (cc, rr) => inMap(m, cc, rr) && isDirt(m.tiles[rr][cc]);
        let q = 56;
        if (d(c, r - 1)) q += 1;
        if (d(c - 1, r)) q += 2;
        if (d(c + 1, r)) q += 4;
        if (d(c, r + 1)) q += 8;
        return q;
    }

    // Grass flourish: the game seeds Lua's RNG per tile, which can't be
    // reproduced here, so this picks a decoration with a hash instead. The
    // pattern differs from the game's but looks the same overall.
    function flourishQuad(c, r) {
        let h = ((c + 1) * 73856093) ^ ((r + 1) * 19349663);
        h = (h ^ (h >>> 13)) * 1274126177;
        return 11 + (Math.abs(h) % 12);
    }

    // Cliff / pit wall sprites (mountain.lua).
    // With slopes: no wall when the tile in front is joined to this one (the
    // ground just slants down to it), and a sloped south edge clips the wall's
    // top to match (k = this tile's corners).
    function drawWall(ctx, m, img, c, r, x, y, k) {
        const own = heightAt(m, c, r);
        if (inMap(m, c, r + 1) && joined(own, heightAt(m, c, r + 1))) return;
        const bottom = faceBottom(m, c, r);
        const sw = k ? k[2] : own, se = k ? k[3] : own;
        const top = Math.max(sw, se);
        if (bottom >= top) return;
        if (sw !== se) {
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(x, y + TS - sw); ctx.lineTo(x + TS, y + TS - se);
            ctx.lineTo(x + TS, y + TS - bottom + 1); ctx.lineTo(x, y + TS - bottom + 1);
            ctx.closePath(); ctx.clip();
            drawWallSprites(ctx, m, img, c, r, x, y, top, bottom);
            ctx.restore();
        } else {
            drawWallSprites(ctx, m, img, c, r, x, y, top, bottom);
        }
    }

    function drawWallSprites(ctx, m, img, c, r, x, y, top, bottom) {
        const rows = (top - bottom) / TS;
        const covers = (cc, band) => {
            if (!inMap(m, cc, r)) return false;
            const t = heightAt(m, cc, r);
            const b = Math.min(t, faceBottom(m, cc, r));
            return t > band && b <= band;
        };
        for (let k = 0; k < rows; k++) {
            let q = rows === 1 ? 23 : (k === 0 ? 27 : (k === rows - 1 ? 35 : 31));
            const band = bottom + k * TS;
            if (covers(c + 1, band)) q += 1;
            if (covers(c - 1, band)) q += 2;
            drawQuad(ctx, img, q, x, y - band);
        }
        drawQuad(ctx, img, 45, x, y - bottom - (rows - 1) * TS, rows);
    }

    // ------------------------------------------------------------------
    // HEIGHT view
    // ------------------------------------------------------------------

    // Draws the area [c0..c1] x [r0..r1] (plus margins) in the 3/4 view.
    // Coordinates are world pixels; the caller sets up the transform.
    function drawHeightView(ctx, m, imgs, opts) {
        const { c0, c1, r0, r1 } = opts.range;
        slopesOn = opts.slopes !== false;
        // Rows above / below the visible range whose content can reach into
        // view (tall cliffs, trees, pits sinking down).
        const maxH = opts.maxHeight, minH = opts.minHeight;
        const rStart = Math.max(0, r0 - Math.ceil(-minH / TS) - 1);
        const rEnd = Math.min(m.height - 1, r1 + Math.ceil((maxH + 260) / TS) + 1);
        const cStart = Math.max(0, c0 - 9), cEnd = Math.min(m.width - 1, c1 + 9);

        for (let r = rStart; r <= rEnd; r++) {
            const sprites = [];
            for (let c = cStart; c <= cEnd; c++) {
                const t = m.tiles[r][c], h = m.heights[r][c];
                const x = c * TS, y = r * TS;      // tile at ground level
                const k = corners(m, c, r);
                drawWall(ctx, m, imgs.land, c, r, x, y, k);
                drawTop(ctx, imgs.land, grassQuad(m, c, r), x, y, k);
                if (isDirt(t)) drawTop(ctx, imgs.land, dirtQuad(m, c, r), x, y, k);
                if (t === 1) drawTop(ctx, imgs.land, flourishQuad(c, r), x, y, k);
                shadeSlope(ctx, m, c, r, x, y, k);

                // Things standing on the tile sit at the ground height under their base.
                if (opts.showWater && m.water[r][c] > 0) drawWaterTile(ctx, x, y, Math.max(...k), m.water[r][c]);

                if (isCrop(t)) {
                    const hc = surfaceAt(m, x + 15, y + 27);
                    sprites.push({ sortY: y + 24, draw: () => drawCrop(ctx, imgs, t, x, y - Math.round(hc)) });
                }
                if (isTree(t)) {
                    const ht = surfaceAt(m, x + TREE_BASE_X, y + TREE_BASE_Y);
                    sprites.push({ sortY: y + TREE_BASE_Y, draw: () => drawTree(ctx, imgs, t, x, y - Math.round(ht), opts.treeAlpha) });
                }
            }
            if (opts.showObjects) {
                for (const o of m.objects) {
                    if (Math.floor((o.y - 4) / TS) === r) {
                        sprites.push({ sortY: o.y, draw: () => drawObject(ctx, imgs, m, o, true, opts.selected === o) });
                    }
                }
            }
            sprites.sort((a, b) => a.sortY - b.sortY);
            for (const s of sprites) s.draw();

            // Floating blocks are in front of everything else in their row.
            if (opts.showBlocks) {
                for (let c = cStart; c <= cEnd; c++) {
                    const b = m.blocks[r][c];
                    if (b != null) drawBlock(ctx, imgs, c * TS, r * TS, b);
                }
            }
        }
    }

    function drawWaterTile(ctx, x, y, h, depth) {
        const S = h + depth;
        const a = Math.min(0.85, 0.35 + depth / 80);
        ctx.fillStyle = "rgba(40, 110, 170, " + a + ")";
        ctx.fillRect(x, y - S, TS, TS);                       // surface
        ctx.fillStyle = "rgba(20, 70, 120, " + Math.min(0.9, a + 0.1) + ")";
        ctx.fillRect(x, y + TS - S, TS, depth);               // front face down to the floor
    }

    function drawCrop(ctx, imgs, t, x, y) {
        // crop.lua: drawn at (tile + 15, tile + 27) with origin (55, 85).
        const draw = (n) => ctx.drawImage(imgs.crop, (n - 1) * 112, 0, 112, 112, x + 15 - 55, y + 27 - 85, 112, 112);
        if (t % 2 === 1) draw(1);                              // wet soil under watered crops
        draw(Math.floor((t - 72) / 2) + 2);
    }

    function drawTree(ctx, imgs, t, x, y, alpha) {
        const k = TREES[t];
        ctx.globalAlpha = alpha == null ? 1 : alpha;
        ctx.drawImage(imgs.tree, k.sx, 0, 480, 480, x + TREE_BASE_X - k.anchorX, y + TREE_BASE_Y - k.anchorY, 480, 480);
        ctx.globalAlpha = 1;
    }

    function drawBlock(ctx, imgs, x, y, bottom) {
        ctx.drawImage(imgs.block, 0, 32, 32, 32, x, y - bottom, 32, 32);        // front face
        ctx.drawImage(imgs.block, 0, 0, 32, 32, x, y - bottom - TS, 32, 32);    // top
    }

    // Objects: pages use their art, the spawn shows the player, anything
    // else a labelled marker. `lifted` draws them at their ground height.
    function drawObject(ctx, imgs, m, o, lifted, selected) {
        const h = lifted ? Math.round(surfaceAt(m, o.x, o.y - 4)) : 0;
        const box = objectBox(m, o, lifted);
        if (o.type === "page") {
            ctx.drawImage(imgs.objects, 0, 0, 64, 64, o.x - 32, o.y - 64 - h, 64, 64);
        } else if (o.type === "spawn") {
            ctx.drawImage(imgs.player, 0, 0, 112, 112, o.x + 16 - 56, o.y - 84 - h, 112, 112);
        } else {
            ctx.fillStyle = "rgba(255, 210, 60, 0.85)";
            ctx.beginPath(); ctx.arc(o.x, o.y - 8 - h, 7, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = "#222"; ctx.font = "bold 9px sans-serif"; ctx.textAlign = "center";
            ctx.fillText(String(o.type || "?").slice(0, 2).toUpperCase(), o.x, o.y - 5 - h);
        }
        if (selected) {
            ctx.strokeStyle = "#ffeb3b"; ctx.lineWidth = 1.5;
            ctx.strokeRect(box.x + 0.5, box.y + 0.5, box.w, box.h);
        }
    }

    // The clickable rectangle of an object, in world pixels.
    function objectBox(m, o, lifted) {
        const h = lifted ? Math.round(surfaceAt(m, o.x, o.y - 4)) : 0;
        if (o.type === "page") return { x: o.x - 14, y: o.y - 60 - h, w: 28, h: 40 };
        if (o.type === "spawn") return { x: o.x + 2, y: o.y - 64 - h, w: 28, h: 64 };
        return { x: o.x - 8, y: o.y - 16 - h, w: 16, h: 16 };
    }

    // ------------------------------------------------------------------
    // FLAT view
    // ------------------------------------------------------------------

    function heightColour(h) {
        if (h > 0) {
            const t = Math.min(1, h / 320);
            return "rgba(" + Math.round(230) + "," + Math.round(160 - 120 * t) + "," + Math.round(40) + "," + (0.25 + 0.45 * t) + ")";
        }
        const t = Math.min(1, -h / 160);
        return "rgba(90," + Math.round(80 - 40 * t) + ",210," + (0.3 + 0.45 * t) + ")";
    }

    function drawFlatView(ctx, m, imgs, opts) {
        const { c0, c1, r0, r1 } = opts.range;
        for (let r = r0; r <= r1; r++) {
            for (let c = c0; c <= c1; c++) {
                const t = m.tiles[r][c], h = m.heights[r][c];
                const x = c * TS, y = r * TS;
                drawQuad(ctx, imgs.land, 1, x, y);
                if (isDirt(t)) drawQuad(ctx, imgs.land, dirtQuad(m, c, r), x, y);
                if (t === 10) { ctx.fillStyle = "rgba(40,120,30,0.55)"; ctx.fillRect(x + 4, y + 4, 24, 24); }
                if (isCrop(t)) {
                    const n = Math.floor((t - 72) / 2) + 2;
                    if (t % 2 === 1) ctx.drawImage(imgs.crop, 0, 0, 112, 112, x, y, 32, 32);
                    ctx.drawImage(imgs.crop, (n - 1) * 112 + 24, 24, 64, 64, x, y, 32, 32);
                }
                if (isTree(t)) {
                    const k = TREES[t];
                    ctx.drawImage(imgs.tree, k.sx + 150, 20, 180, 250, x + 3, y, 26, 32);
                }
                if (opts.showHeights && h !== 0) {
                    ctx.fillStyle = heightColour(h);
                    ctx.fillRect(x, y, TS, TS);
                }
                if (opts.showWater && m.water[r][c] > 0) {
                    ctx.fillStyle = "rgba(40,120,220," + Math.min(0.75, 0.3 + m.water[r][c] / 60) + ")";
                    ctx.fillRect(x, y, TS, TS);
                }
                if (opts.showBlocks && m.blocks[r][c] != null) {
                    ctx.strokeStyle = "#f5c16c"; ctx.lineWidth = 2;
                    ctx.strokeRect(x + 4, y + 4, TS - 8, TS - 8);
                    ctx.fillStyle = "rgba(205,160,95,0.55)";
                    ctx.fillRect(x + 6, y + 6, TS - 12, TS - 12);
                }
            }
        }
        // Labels only when zoomed in enough to read them.
        if (opts.zoom >= 1.5) {
            ctx.textAlign = "center";
            ctx.font = "bold 10px sans-serif";
            for (let r = r0; r <= r1; r++) {
                for (let c = c0; c <= c1; c++) {
                    const x = c * TS, y = r * TS;
                    const h = m.heights[r][c];
                    const labels = [];
                    if (opts.showHeights && h !== 0) labels.push((h > 0 ? "+" : "") + (h % TS === 0 ? h / TS : (h / TS).toFixed(2)));
                    if (opts.showBlocks && m.blocks[r][c] != null) labels.push("B" + m.blocks[r][c]);
                    if (opts.showWater && m.water[r][c] > 0) labels.push("~" + Math.round(m.water[r][c]));
                    labels.forEach((s, i) => {
                        ctx.fillStyle = "rgba(0,0,0,0.6)";
                        ctx.fillText(s, x + TS / 2 + 1, y + 12 + i * 10);
                        ctx.fillStyle = "#fff";
                        ctx.fillText(s, x + TS / 2, y + 11 + i * 10);
                    });
                }
            }
        }
        if (opts.showObjects) {
            for (const o of m.objects) drawObject(ctx, imgs, m, o, false, opts.selected === o);
        }
    }

    // ------------------------------------------------------------------
    // Picking: which tile is under a world-space point?
    // ------------------------------------------------------------------

    // FLAT view: simply the grid cell.
    function pickFlat(m, wx, wy) {
        const c = Math.floor(wx / TS), r = Math.floor(wy / TS);
        return inMap(m, c, r) ? { c, r } : null;
    }

    // HEIGHT view: tiles are drawn lifted by their height, so search the
    // rows that could cover this screen point, front-most (lowest) first,
    // and return the first whose top or wall contains it.
    function pickHeight(m, wx, wy, maxH, minH) {
        const c = Math.floor(wx / TS);
        if (c < 0 || c >= m.width) return null;
        const rFirst = Math.min(m.height - 1, Math.floor((wy + maxH + TS) / TS) + 1);
        const rLast = Math.max(0, Math.floor((wy + minH) / TS) - 1);
        for (let r = rFirst; r >= rLast; r--) {
            // A floating block is drawn in front of everything in its row.
            const b = m.blocks[r][c];
            if (b != null && wy >= r * TS - b - TS && wy < r * TS - b + TS) return { c, r, onBlock: true };
            // The top's edges at this column (sloped tiles slant), then the
            // wall below it unless the tile in front is joined by a slope.
            const k = corners(m, c, r), f = (wx - c * TS) / TS;
            const hN = k[0] + (k[1] - k[0]) * f, hS = k[2] + (k[3] - k[2]) * f;
            const yTop = r * TS - hN;
            const front = inMap(m, c, r + 1) && joined(m.heights[r][c], m.heights[r + 1][c]);
            const yBottom = r * TS + TS - (front ? hS : Math.min(hS, faceBottom(m, c, r)));
            if (wy >= yTop && wy < yBottom) return { c, r };
        }
        return null;
    }

    root.MapRender = {
        TS, TILE_TYPES, typeName, isTree, isCrop, TREES,
        drawHeightView, drawFlatView, drawCrop, drawTree, drawQuad,
        pickFlat, pickHeight, objectBox, heightAt, surfaceAt, corners, SLOPE_LIMIT,
    };
})(window);
