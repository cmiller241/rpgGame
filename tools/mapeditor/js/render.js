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
    function zAt(m, c, r) { return -heightAt(m, c, r); }   // the game's z (negative = up)

    // Bottom of tile (c, r)'s south wall: the lower of ground level and the
    // tile in front of it (terrain:faceBottom).
    function faceBottom(m, c, r) { return Math.min(0, heightAt(m, c, r + 1)); }

    // ------------------------------------------------------------------
    // Sprite helpers
    // ------------------------------------------------------------------

    // img/sprites2.png is a grid of 32 px tiles, 11 per row, numbered from 1.
    function drawQuad(ctx, img, n, x, y, scaleY) {
        const cols = Math.floor(img.width / TS);
        const sx = ((n - 1) % cols) * TS, sy = Math.floor((n - 1) / cols) * TS;
        ctx.drawImage(img, sx, sy, TS, TS, x, y, TS, TS * (scaleY || 1));
    }

    // Grass top (grass.lua): +1 if the tile above is not lower, +2 right, +4 left.
    function grassQuad(m, c, r) {
        const z = zAt(m, c, r);
        let q = 1;
        if (r > 0 && zAt(m, c, r - 1) <= z) q += 1;
        if (c < m.width - 1 && zAt(m, c + 1, r) <= z) q += 2;
        if (c > 0 && zAt(m, c - 1, r) <= z) q += 4;
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
    function drawWall(ctx, m, img, c, r, x, y) {
        const top = heightAt(m, c, r);
        const bottom = faceBottom(m, c, r);
        if (bottom >= top) return;
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
                drawWall(ctx, m, imgs.land, c, r, x, y);
                drawQuad(ctx, imgs.land, grassQuad(m, c, r), x, y - h);
                if (isDirt(t)) drawQuad(ctx, imgs.land, dirtQuad(m, c, r), x, y - h);
                if (t === 1) drawQuad(ctx, imgs.land, flourishQuad(c, r), x, y - h);

                if (opts.showWater && m.water[r][c] > 0) drawWaterTile(ctx, x, y, h, m.water[r][c]);

                if (isCrop(t)) sprites.push({ sortY: y + 24, draw: () => drawCrop(ctx, imgs, t, x, y - h) });
                if (isTree(t)) sprites.push({ sortY: y + TREE_BASE_Y, draw: () => drawTree(ctx, imgs, t, x, y - h, opts.treeAlpha) });
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
        const h = lifted ? heightAt(m, Math.floor(o.x / TS), Math.floor((o.y - 4) / TS)) : 0;
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
        const h = lifted ? heightAt(m, Math.floor(o.x / TS), Math.floor((o.y - 4) / TS)) : 0;
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
            const h = m.heights[r][c];
            const yTop = r * TS - h;
            const yBottom = r * TS + TS - Math.min(h, faceBottom(m, c, r));
            if (wy >= yTop && wy < yBottom) return { c, r };
        }
        return null;
    }

    root.MapRender = {
        TS, TILE_TYPES, typeName, isTree, isCrop, TREES,
        drawHeightView, drawFlatView, drawCrop, drawTree, drawQuad,
        pickFlat, pickHeight, objectBox, heightAt,
    };
})(window);
