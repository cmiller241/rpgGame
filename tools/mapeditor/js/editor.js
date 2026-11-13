// editor.js
//
// The map editor's state, tools, input handling, undo/redo, file handling
// and side panels. Drawing lives in render.js; reading/writing map files in
// luadata.js.
//
// TOOLS
//   1 Tile     paint tile types (grass, dirt, crops, trees...)
//   2 Height   raise / lower / set ground height
//   3 Block    place / remove floating blocks
//   4 Water    add / set / erase starting water
//   5 Objects  select, move, add and delete objects (spawn, Bible pages, NPCs...)
//
// MOUSE
//   left = apply tool, right = the opposite (lower / remove / erase / delete)
//   Alt+click = pick the tile type / height / block / water under the cursor
//   middle-drag or Space+drag = pan, wheel = zoom

(function () {
    "use strict";

    const R = window.MapRender;
    const TS = R.TS;

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------

    const state = {
        map: LuaData.blankMap(100, 100),
        view: "height",          // "flat" | "height"
        zoom: 2,
        camX: 0, camY: 0,        // world px at the canvas's top-left
        tool: "tile",
        tileType: 1,
        heightMode: "raise",     // raise | lower | set
        heightStep: 32,
        heightValue: 0,
        blockBottom: 24,
        waterMode: "add",        // add | set
        waterAmount: 8,
        newObjectType: "page",
        brush: 1,
        show: { grid: true, heights: true, water: true, blocks: true, objects: true },
        hover: null,             // { c, r, wx, wy }
        selected: null,          // selected object
        fileHandle: null,        // File System Access handle, when available
        fileName: "map01.lua",
        dirty: false,
    };

    const ZOOMS = [0.25, 0.5, 1, 2, 3, 4];
    const OBJECT_TYPES = ["page", "spawn", "npc", "sign", "chest"];
    // Properties a new object of each type starts with.
    const OBJECT_DEFAULTS = {
        page: { verse: "", message: "", tool: 1, toolMessage: "" },
        spawn: {},
        npc: { name: "", dialogue: "" },
        sign: { text: "" },
        chest: { item: "" },
    };

    const canvas = document.getElementById("canvas");
    const ctx = canvas.getContext("2d");
    const $ = (id) => document.getElementById(id);

    // ------------------------------------------------------------------
    // Game art
    // ------------------------------------------------------------------

    const imgs = {};
    const IMAGE_FILES = {
        land: "sprites2.png", tree: "tree4.png", crop: "crop.png",
        block: "block.png", objects: "objects.png", player: "sprites-fixedgrid.png",
    };
    function loadImages() {
        return Promise.all(Object.entries(IMAGE_FILES).map(([key, file]) => new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => { imgs[key] = img; resolve(); };
            img.onerror = () => reject(new Error("Couldn't load ../../img/" + file));
            img.src = "../../img/" + file;
        })));
    }

    // ------------------------------------------------------------------
    // Map helpers
    // ------------------------------------------------------------------

    function extents() {
        let maxH = 0, minH = 0;
        const m = state.map;
        for (let r = 0; r < m.height; r++) for (let c = 0; c < m.width; c++) {
            const h = m.heights[r][c];
            if (h > maxH) maxH = h;
            if (h < minH) minH = h;
            if (m.blocks[r][c] != null) maxH = Math.max(maxH, m.blocks[r][c] + TS);
        }
        return { maxH, minH };
    }
    let ext = extents();

    // Tiles covered by the brush around (c, r).
    function brushTiles(c, r) {
        const half = Math.floor(state.brush / 2), out = [];
        for (let dr = -half; dr <= half; dr++) for (let dc = -half; dc <= half; dc++) {
            const cc = c + dc, rr = r + dr;
            if (rr >= 0 && rr < state.map.height && cc >= 0 && cc < state.map.width) out.push([cc, rr]);
        }
        return out;
    }

    // ------------------------------------------------------------------
    // Undo / redo
    // ------------------------------------------------------------------
    //
    // A "stroke" (mouse down -> up) collects every cell change it makes;
    // undo puts the old values back. Object edits store before/after copies
    // of the object list.

    const undoStack = [], redoStack = [];
    let stroke = null;

    function beginStroke() { stroke = { cells: new Map(), objectsBefore: null }; }

    // Sets layer[r][c] = value, remembering the first old value this stroke.
    function setCell(layer, c, r, value) {
        const grid = state.map[layer];
        if (grid[r][c] === value) return false;
        const key = layer + ":" + c + ":" + r;
        if (stroke && !stroke.cells.has(key)) stroke.cells.set(key, { layer, c, r, old: grid[r][c] });
        grid[r][c] = value;
        return true;
    }

    function rememberObjects() {
        if (stroke && !stroke.objectsBefore) stroke.objectsBefore = cloneObjects();
    }
    const cloneObjects = () => state.map.objects.map(o => Object.assign({}, o));

    function endStroke() {
        if (!stroke) return;
        const action = { cells: [], objectsBefore: stroke.objectsBefore, objectsAfter: null };
        for (const ch of stroke.cells.values()) {
            const now = state.map[ch.layer][ch.r][ch.c];
            if (now !== ch.old) action.cells.push(Object.assign({}, ch, { now }));
        }
        if (action.objectsBefore) action.objectsAfter = cloneObjects();
        stroke = null;
        if (action.cells.length || action.objectsBefore) {
            undoStack.push(action);
            if (undoStack.length > 200) undoStack.shift();
            redoStack.length = 0;
            markDirty();
        }
    }

    function applyAction(action, undo) {
        for (const ch of action.cells) state.map[ch.layer][ch.r][ch.c] = undo ? ch.old : ch.now;
        if (action.objectsBefore) {
            state.map.objects = (undo ? action.objectsBefore : action.objectsAfter).map(o => Object.assign({}, o));
            state.selected = null;
        }
        markDirty();
        refreshPanels();
    }
    function undo() { const a = undoStack.pop(); if (a) { applyAction(a, true); redoStack.push(a); } }
    function redo() { const a = redoStack.pop(); if (a) { applyAction(a, false); undoStack.push(a); } }

    function markDirty() {
        state.dirty = true;
        ext = extents();
        updateTitle();
        refreshMapInfo();  // block/water/object counts can change with any edit
        requestDraw();
    }

    // ------------------------------------------------------------------
    // Tools
    // ------------------------------------------------------------------

    // Tiles already changed during this stroke (so dragging over a tile
    // raises it once, not every mouse move).
    let strokeTouched = new Set();

    // Applies the current tool at tile (c, r). `alt` = the right-button
    // (opposite) action.
    function applyTool(c, r, alt) {
        const m = state.map;
        for (const [cc, rr] of brushTiles(c, r)) {
            const key = cc + ":" + rr;
            if (strokeTouched.has(key)) continue;
            strokeTouched.add(key);
            switch (state.tool) {
                case "tile":
                    setCell("tiles", cc, rr, alt ? 1 : state.tileType);
                    break;
                case "height": {
                    const h = m.heights[rr][cc];
                    let mode = state.heightMode;
                    if (alt) mode = mode === "raise" ? "lower" : (mode === "lower" ? "raise" : "set0");
                    let nh = h;
                    if (mode === "raise") nh = h + state.heightStep;
                    else if (mode === "lower") nh = h - state.heightStep;
                    else if (mode === "set") nh = state.heightValue;
                    else if (mode === "set0") nh = 0;
                    nh = Math.max(-512, Math.min(1000, nh));
                    // Ground can't rise into a floating block above it.
                    const b = m.blocks[rr][cc];
                    if (b != null && nh > b) nh = b;
                    setCell("heights", cc, rr, nh);
                    break;
                }
                case "block":
                    if (alt) setCell("blocks", cc, rr, null);
                    else setCell("blocks", cc, rr, Math.max(m.heights[rr][cc], state.blockBottom + m.heights[rr][cc]));
                    break;
                case "water":
                    if (alt) setCell("water", cc, rr, 0);
                    else if (state.waterMode === "add") setCell("water", cc, rr, Math.min(320, m.water[rr][cc] + state.waterAmount));
                    else setCell("water", cc, rr, state.waterAmount);
                    break;
            }
        }
        requestDraw();
    }

    // Alt+click: copy the value under the cursor into the current tool.
    function pickValue(c, r) {
        const m = state.map;
        if (state.tool === "tile") state.tileType = m.tiles[r][c];
        if (state.tool === "height") { state.heightMode = "set"; state.heightValue = m.heights[r][c]; }
        if (state.tool === "block" && m.blocks[r][c] != null) state.blockBottom = m.blocks[r][c] - m.heights[r][c];
        if (state.tool === "water") { state.waterMode = "set"; state.waterAmount = m.water[r][c]; }
        buildToolOptions();
    }

    // ------------------------------------------------------------------
    // Objects
    // ------------------------------------------------------------------

    function objectAt(wx, wy, screenWy) {
        const lifted = state.view === "height";
        const y = lifted ? screenWy : wy;
        for (let i = state.map.objects.length - 1; i >= 0; i--) {
            const o = state.map.objects[i];
            const b = R.objectBox(state.map, o, lifted);
            if (wx >= b.x && wx <= b.x + b.w && y >= b.y && y <= b.y + b.h) return o;
        }
        return null;
    }

    function addObject(type, x, y) {
        rememberObjects();
        // Only one spawn point: placing a new one moves it.
        if (type === "spawn") state.map.objects = state.map.objects.filter(o => o.type !== "spawn");
        const o = Object.assign({ type, x: Math.round(x), y: Math.round(y) }, OBJECT_DEFAULTS[type] || {});
        state.map.objects.push(o);
        state.selected = o;
        refreshPanels();
    }

    function deleteObject(o) {
        if (!o) return;
        beginStroke();
        rememberObjects();
        state.map.objects = state.map.objects.filter(x => x !== o);
        if (state.selected === o) state.selected = null;
        endStroke();
        refreshPanels();
    }

    // ------------------------------------------------------------------
    // Coordinates
    // ------------------------------------------------------------------

    // Canvas pixel -> "screen-world" pixel (before undoing the height lift).
    function toWorld(px, py) {
        return { x: px / state.zoom + state.camX, y: py / state.zoom + state.camY };
    }

    // The tile under a canvas pixel, in the current view.
    function pickTile(px, py) {
        const w = toWorld(px, py);
        const t = state.view === "flat"
            ? R.pickFlat(state.map, w.x, w.y)
            : R.pickHeight(state.map, w.x, w.y, ext.maxH, ext.minH);
        return t;
    }

    // Ground-plane world position for placing/moving objects: in the height
    // view, the point on the tile's top under the cursor.
    function groundPoint(px, py) {
        const w = toWorld(px, py);
        if (state.view === "flat") return w;
        const t = pickTile(px, py);
        const h = t ? state.map.heights[t.r][t.c] : 0;
        return { x: w.x, y: w.y + h };
    }

    // ------------------------------------------------------------------
    // Drawing
    // ------------------------------------------------------------------

    let drawQueued = false;
    function requestDraw() {
        if (drawQueued) return;
        drawQueued = true;
        requestAnimationFrame(draw);
    }

    function draw() {
        drawQueued = false;
        const W = canvas.width, H = canvas.height;
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.fillStyle = "#14161a";
        ctx.fillRect(0, 0, W, H);
        if (!imgs.land) return;

        const z = state.zoom, m = state.map;
        ctx.imageSmoothingEnabled = false;
        ctx.setTransform(z, 0, 0, z, -state.camX * z, -state.camY * z);

        const c0 = Math.max(0, Math.floor(state.camX / TS)), c1 = Math.min(m.width - 1, Math.floor((state.camX + W / z) / TS));
        const r0 = Math.max(0, Math.floor(state.camY / TS)), r1 = Math.min(m.height - 1, Math.floor((state.camY + H / z) / TS));
        const opts = {
            range: { c0, c1, r0, r1 }, zoom: z, maxHeight: ext.maxH, minHeight: ext.minH,
            showHeights: state.show.heights, showWater: state.show.water,
            showBlocks: state.show.blocks, showObjects: state.show.objects,
            selected: state.selected,
        };

        // Map edge
        ctx.fillStyle = "#2a2f36";
        ctx.fillRect(-4, -4, m.width * TS + 8, m.height * TS + 8);

        if (state.view === "flat") R.drawFlatView(ctx, m, imgs, opts);
        else R.drawHeightView(ctx, m, imgs, opts);

        // Grid (flat view: tile cells; height view: each tile's top outline is too busy, so just cells near the cursor)
        if (state.show.grid && state.view === "flat" && z >= 0.5) {
            ctx.strokeStyle = "rgba(0,0,0,0.25)";
            ctx.lineWidth = 1 / z;
            ctx.beginPath();
            for (let c = c0; c <= c1 + 1; c++) { ctx.moveTo(c * TS, r0 * TS); ctx.lineTo(c * TS, (r1 + 1) * TS); }
            for (let r = r0; r <= r1 + 1; r++) { ctx.moveTo(c0 * TS, r * TS); ctx.lineTo((c1 + 1) * TS, r * TS); }
            ctx.stroke();
        }

        // Brush outline at the hovered tile
        if (state.hover && state.tool !== "objects") {
            ctx.lineWidth = 2 / z;
            ctx.strokeStyle = "#ffeb3b";
            for (const [cc, rr] of brushTiles(state.hover.c, state.hover.r)) {
                if (state.view === "flat") {
                    ctx.strokeRect(cc * TS, rr * TS, TS, TS);
                } else {
                    const b = m.blocks[rr][cc];
                    if (state.tool === "block" && b != null) ctx.strokeRect(cc * TS, rr * TS - b - TS, TS, 2 * TS);
                    else ctx.strokeRect(cc * TS, rr * TS - m.heights[rr][cc], TS, TS);
                }
            }
        }
    }

    function resize() {
        const wrap = $("canvas-wrap");
        canvas.width = wrap.clientWidth;
        canvas.height = wrap.clientHeight;
        requestDraw();
    }

    function setZoom(newZoom, anchorPx, anchorPy) {
        const ax = anchorPx == null ? canvas.width / 2 : anchorPx;
        const ay = anchorPy == null ? canvas.height / 2 : anchorPy;
        const before = toWorld(ax, ay);
        state.zoom = newZoom;
        state.camX = before.x - ax / newZoom;
        state.camY = before.y - ay / newZoom;
        $("zoom-label").textContent = (newZoom < 1 ? newZoom : newZoom) + "×";
        requestDraw();
    }
    function stepZoom(dir, ax, ay) {
        const i = ZOOMS.indexOf(state.zoom);
        const ni = Math.max(0, Math.min(ZOOMS.length - 1, (i < 0 ? 3 : i) + dir));
        setZoom(ZOOMS[ni], ax, ay);
    }

    // ------------------------------------------------------------------
    // Mouse
    // ------------------------------------------------------------------

    let mouse = { down: false, button: 0, panning: false, lastX: 0, lastY: 0, dragObject: null, dragOffset: null };
    let spaceHeld = false;

    canvas.addEventListener("contextmenu", (e) => e.preventDefault());

    canvas.addEventListener("mousedown", (e) => {
        const px = e.offsetX, py = e.offsetY;
        mouse.lastX = px; mouse.lastY = py;
        if (e.button === 1 || (e.button === 0 && spaceHeld)) {
            mouse.panning = true;
            e.preventDefault();
            return;
        }
        mouse.down = true; mouse.button = e.button;
        const alt = e.button === 2;

        if (state.tool === "objects") {
            const w = toWorld(px, py);
            const g = groundPoint(px, py);
            const hit = objectAt(g.x, g.y, w.y);
            if (alt) { deleteObject(hit); mouse.down = false; return; }
            beginStroke();
            if (hit) {
                state.selected = hit;
                mouse.dragObject = hit;
                mouse.dragOffset = { x: hit.x - g.x, y: hit.y - g.y };
                rememberObjects();
            } else {
                addObject(state.newObjectType, g.x, g.y);
                mouse.dragObject = state.selected;
                mouse.dragOffset = { x: 0, y: 0 };
            }
            refreshPanels();
            requestDraw();
            return;
        }

        const t = pickTile(px, py);
        if (!t) return;
        if (e.altKey) { pickValue(t.c, t.r); mouse.down = false; return; }
        beginStroke();
        strokeTouched = new Set();
        applyTool(t.c, t.r, alt);
    });

    window.addEventListener("mousemove", (e) => {
        const rect = canvas.getBoundingClientRect();
        const px = e.clientX - rect.left, py = e.clientY - rect.top;
        if (mouse.panning) {
            state.camX -= (px - mouse.lastX) / state.zoom;
            state.camY -= (py - mouse.lastY) / state.zoom;
            mouse.lastX = px; mouse.lastY = py;
            requestDraw();
            return;
        }
        if (px < 0 || py < 0 || px > canvas.width || py > canvas.height) {
            if (!mouse.down) { state.hover = null; updateHover(); requestDraw(); }
            return;
        }
        const t = pickTile(px, py);
        const w = toWorld(px, py);
        state.hover = t ? { c: t.c, r: t.r, wx: w.x, wy: w.y } : null;
        updateHover();

        if (mouse.down && state.tool === "objects" && mouse.dragObject) {
            const g = groundPoint(px, py);
            mouse.dragObject.x = Math.round(g.x + mouse.dragOffset.x);
            mouse.dragObject.y = Math.round(g.y + mouse.dragOffset.y);
            refreshObjectPanel();
        } else if (mouse.down && t && state.tool !== "objects") {
            applyTool(t.c, t.r, mouse.button === 2);
        }
        requestDraw();
    });

    window.addEventListener("mouseup", () => {
        if (mouse.panning) { mouse.panning = false; return; }
        if (mouse.down) {
            mouse.down = false;
            mouse.dragObject = null;
            endStroke();
            refreshPanels();
        }
    });

    canvas.addEventListener("wheel", (e) => {
        e.preventDefault();
        stepZoom(e.deltaY < 0 ? 1 : -1, e.offsetX, e.offsetY);
    }, { passive: false });

    // ------------------------------------------------------------------
    // Keyboard
    // ------------------------------------------------------------------

    const TOOL_KEYS = { "1": "tile", "2": "height", "3": "block", "4": "water", "5": "objects" };

    window.addEventListener("keydown", (e) => {
        const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement.tagName);
        const ctrl = e.ctrlKey || e.metaKey;
        if (ctrl && e.key.toLowerCase() === "s") { e.preventDefault(); e.shiftKey ? saveAs() : save(); return; }
        if (ctrl && e.key.toLowerCase() === "o") { e.preventDefault(); openFile(); return; }
        if (typing) return;
        if (ctrl && e.key.toLowerCase() === "z") { e.preventDefault(); e.shiftKey ? redo() : undo(); return; }
        if (ctrl && e.key.toLowerCase() === "y") { e.preventDefault(); redo(); return; }
        if (e.key === " ") { spaceHeld = true; e.preventDefault(); return; }
        if (TOOL_KEYS[e.key]) { setTool(TOOL_KEYS[e.key]); return; }
        if (e.key === "Tab") { e.preventDefault(); setView(state.view === "flat" ? "height" : "flat"); return; }
        if (e.key === "+" || e.key === "=") stepZoom(1);
        if (e.key === "-") stepZoom(-1);
        if ((e.key === "Delete" || e.key === "Backspace") && state.selected) deleteObject(state.selected);
        if (e.key === "[") setBrush(Math.max(1, state.brush - 2));
        if (e.key === "]") setBrush(Math.min(9, state.brush + 2));
        const pan = 64 / state.zoom;
        if (e.key === "ArrowLeft") { state.camX -= pan; requestDraw(); }
        if (e.key === "ArrowRight") { state.camX += pan; requestDraw(); }
        if (e.key === "ArrowUp") { state.camY -= pan; requestDraw(); }
        if (e.key === "ArrowDown") { state.camY += pan; requestDraw(); }
    });
    window.addEventListener("keyup", (e) => { if (e.key === " ") spaceHeld = false; });

    // ------------------------------------------------------------------
    // Panels
    // ------------------------------------------------------------------

    function setTool(tool) {
        state.tool = tool;
        document.querySelectorAll("[data-tool]").forEach(b => b.classList.toggle("active", b.dataset.tool === tool));
        buildToolOptions();
        requestDraw();
    }

    function setView(view) {
        state.view = view;
        $("view-flat").classList.toggle("active", view === "flat");
        $("view-height").classList.toggle("active", view === "height");
        requestDraw();
    }

    function setBrush(size) {
        state.brush = size;
        document.querySelectorAll("[data-brush]").forEach(b => b.classList.toggle("active", Number(b.dataset.brush) === size));
        requestDraw();
    }

    // Small icon of a tile type, for the palette.
    function tileIcon(id) {
        const cv = document.createElement("canvas");
        cv.width = 32; cv.height = 32;
        const g = cv.getContext("2d");
        g.imageSmoothingEnabled = false;
        if (!imgs.land) return cv;
        R.drawQuad(g, imgs.land, 1, 0, 0);
        if (id === 56 || R.isCrop(id)) R.drawQuad(g, imgs.land, 56, 0, 0);
        if (id === 10) { g.fillStyle = "rgba(40,120,30,0.6)"; g.fillRect(4, 4, 24, 24); }
        if (R.isCrop(id)) {
            const n = Math.floor((id - 72) / 2) + 2;
            if (id % 2 === 1) g.drawImage(imgs.crop, 0, 0, 112, 112, 0, 0, 32, 32);
            g.drawImage(imgs.crop, (n - 1) * 112 + 24, 24, 64, 64, 0, 0, 32, 32);
        }
        if (R.isTree(id)) g.drawImage(imgs.tree, R.TREES[id].sx + 150, 20, 180, 250, 3, 0, 26, 32);
        return cv;
    }

    function numberInput(label, value, onChange, step) {
        const wrap = document.createElement("label");
        wrap.className = "field";
        wrap.textContent = label + " ";
        const input = document.createElement("input");
        input.type = "number"; input.value = value; input.step = step || 1;
        input.addEventListener("change", () => onChange(Number(input.value)));
        wrap.appendChild(input);
        return wrap;
    }

    function radioRow(options, current, onChange) {
        const row = document.createElement("div");
        row.className = "seg";
        for (const [value, label] of options) {
            const b = document.createElement("button");
            b.textContent = label;
            b.classList.toggle("active", value === current);
            b.addEventListener("click", () => { onChange(value); buildToolOptions(); });
            row.appendChild(b);
        }
        return row;
    }

    function hint(text) {
        const p = document.createElement("p");
        p.className = "hint";
        p.textContent = text;
        return p;
    }

    function buildToolOptions() {
        const box = $("tool-options");
        box.innerHTML = "";
        const h3 = document.createElement("h3");
        box.appendChild(h3);
        if (state.tool === "tile") {
            h3.textContent = "Tile type";
            const grid = document.createElement("div");
            grid.className = "palette";
            for (const t of R.TILE_TYPES) {
                const b = document.createElement("button");
                b.title = t.name + " (" + t.id + ")";
                b.classList.toggle("active", t.id === state.tileType);
                b.appendChild(tileIcon(t.id));
                b.addEventListener("click", () => { state.tileType = t.id; buildToolOptions(); });
                grid.appendChild(b);
            }
            box.appendChild(grid);
            box.appendChild(hint(R.typeName(state.tileType) + ". Right-click paints plain grass."));
        } else if (state.tool === "height") {
            h3.textContent = "Height";
            box.appendChild(radioRow([["raise", "Raise"], ["lower", "Lower"], ["set", "Set"]], state.heightMode, v => state.heightMode = v));
            box.appendChild(numberInput("Step (px)", state.heightStep, v => state.heightStep = v, 8));
            box.appendChild(numberInput("Set to (px)", state.heightValue, v => state.heightValue = v, 8));
            box.appendChild(hint("32 px = one tile. Positive = up, negative = pit. Right-click does the opposite (Set: back to 0). Each tile changes once per drag. Ground won't rise into a block."));
        } else if (state.tool === "block") {
            h3.textContent = "Floating block";
            box.appendChild(numberInput("Gap above ground (px)", state.blockBottom, v => state.blockBottom = v, 8));
            box.appendChild(hint("Places a 32 px block this far above the tile's ground. 24 = easy to jump onto; 64+ = can walk under. Right-click removes."));
        } else if (state.tool === "water") {
            h3.textContent = "Water";
            box.appendChild(radioRow([["add", "Add"], ["set", "Set"]], state.waterMode, v => state.waterMode = v));
            box.appendChild(numberInput("Depth (px)", state.waterAmount, v => state.waterAmount = v, 1));
            box.appendChild(hint("Starting water. In game it flows, levels out and slowly evaporates. 8 px = one W press. Right-click erases."));
        } else {
            h3.textContent = "Objects";
            const sel = document.createElement("select");
            for (const t of OBJECT_TYPES) {
                const o = document.createElement("option");
                o.value = t; o.textContent = t;
                o.selected = t === state.newObjectType;
                sel.appendChild(o);
            }
            sel.addEventListener("change", () => state.newObjectType = sel.value);
            const lab = document.createElement("label");
            lab.className = "field";
            lab.textContent = "New object type ";
            lab.appendChild(sel);
            box.appendChild(lab);
            box.appendChild(hint("Click empty ground to add, drag to move, right-click or Delete to remove. x, y = where it stands (its feet / base)."));
        }
    }

    function updateHover() {
        const el = $("hover-info");
        const hv = state.hover;
        if (!hv) { el.textContent = "—"; return; }
        const m = state.map, c = hv.c, r = hv.r;
        const h = m.heights[r][c], b = m.blocks[r][c], w = m.water[r][c];
        el.innerHTML =
            "<b>Tile</b> " + (c + 1) + ", " + (r + 1) + "<br>" +
            "<b>Type</b> " + R.typeName(m.tiles[r][c]) + "<br>" +
            "<b>Height</b> " + h + " px" + (h % TS === 0 ? " (" + h / TS + " tiles)" : "") + "<br>" +
            "<b>Block</b> " + (b == null ? "none" : "underside " + b + " px") + "<br>" +
            "<b>Water</b> " + (w > 0 ? w + " px" : "none") + "<br>" +
            "<b>World</b> " + Math.round(hv.wx) + ", " + Math.round(hv.wy);
    }

    // Selected object's properties, editable. Values that look like numbers
    // or true/false are saved as such; everything else as text.
    function refreshObjectPanel() {
        const box = $("object-props");
        box.innerHTML = "";
        const o = state.selected;
        if (!o) { box.appendChild(hint(state.tool === "objects" ? "Click an object to edit it." : "Use the Objects tool (5) to select one.")); return; }

        const parse = (s) => {
            if (/^-?\d+(\.\d+)?$/.test(s.trim())) return Number(s);
            if (s === "true") return true;
            if (s === "false") return false;
            return s;
        };
        const commit = (fn) => { beginStroke(); rememberObjects(); fn(); endStroke(); requestDraw(); };

        for (const key of ["type", "x", "y"].concat(Object.keys(o).filter(k => !["type", "x", "y"].includes(k)))) {
            const row = document.createElement("div");
            row.className = "prop";
            const name = document.createElement("span");
            name.textContent = key;
            const long = typeof o[key] === "string" && (o[key].length > 30 || key === "message");
            const input = document.createElement(long ? "textarea" : "input");
            input.value = o[key];
            if (long) input.rows = 4;
            input.addEventListener("change", () => commit(() => {
                o[key] = (key === "type") ? input.value : parse(input.value);
            }));
            row.appendChild(name);
            row.appendChild(input);
            if (!["type", "x", "y"].includes(key)) {
                const del = document.createElement("button");
                del.textContent = "×";
                del.title = "Remove property";
                del.addEventListener("click", () => { commit(() => delete o[key]); refreshObjectPanel(); });
                row.appendChild(del);
            }
            box.appendChild(row);
        }
        const add = document.createElement("button");
        add.textContent = "+ Property";
        add.addEventListener("click", () => {
            const key = prompt("Property name (letters, numbers, _):");
            if (key && /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) && !(key in o)) {
                commit(() => o[key] = "");
                refreshObjectPanel();
            }
        });
        const del = document.createElement("button");
        del.textContent = "Delete object";
        del.addEventListener("click", () => deleteObject(o));
        const buttons = document.createElement("div");
        buttons.className = "buttons";
        buttons.appendChild(add);
        buttons.appendChild(del);
        box.appendChild(buttons);
    }

    function refreshMapInfo() {
        const m = state.map;
        let blocks = 0, wet = 0;
        for (let r = 0; r < m.height; r++) for (let c = 0; c < m.width; c++) {
            if (m.blocks[r][c] != null) blocks++;
            if (m.water[r][c] > 0) wet++;
        }
        $("map-info").innerHTML =
            m.width + " × " + m.height + " tiles<br>" +
            "Height " + ext.minH + " … " + ext.maxH + " px<br>" +
            blocks + " blocks, " + wet + " wet tiles<br>" +
            m.objects.length + " objects";
    }

    function refreshPanels() {
        refreshObjectPanel();
        refreshMapInfo();
        updateHover();
    }

    function updateTitle() {
        const label = state.fileName + (state.dirty ? " •" : "");
        $("file-label").textContent = label;
        document.title = (state.dirty ? "• " : "") + state.fileName + " — Map Editor";
    }

    function status(msg, isError) {
        const el = $("status");
        el.textContent = msg;
        el.className = isError ? "error" : "";
        clearTimeout(status.timer);
        status.timer = setTimeout(() => { el.textContent = ""; }, 6000);
    }

    // ------------------------------------------------------------------
    // Files
    // ------------------------------------------------------------------
    //
    // Chrome/Edge: Open/Save use the File System Access API, so Save writes
    // straight back to the file you opened. Other browsers: Open uses a file
    // picker and Save downloads the file.

    const PICKER_TYPES = [{ description: "Lua map file", accept: { "text/plain": [".lua"] } }];

    function loadText(text, name) {
        let model;
        try {
            model = LuaData.parseMapFile(text);
        } catch (err) {
            status("Couldn't read " + name + ": " + err.message, true);
            return false;
        }
        state.map = model;
        state.fileName = name;
        state.selected = null;
        state.dirty = !!model.legacy;
        undoStack.length = 0; redoStack.length = 0;
        ext = extents();
        // Start looking at the spawn point if there is one.
        const spawn = model.objects.find(o => o.type === "spawn");
        const fx = spawn ? spawn.x : model.width * TS / 2, fy = spawn ? spawn.y : model.height * TS / 2;
        state.camX = fx - canvas.width / 2 / state.zoom;
        state.camY = fy - canvas.height / 2 / state.zoom;
        if (model.legacy) {
            status("Imported an old-format map. Its Bible pages lived in src/objects.lua, not the map, so add them as objects. Save to write the new format.");
        } else {
            status("Opened " + name);
        }
        updateTitle();
        refreshPanels();
        requestDraw();
        return true;
    }

    async function openFile() {
        if (state.dirty && !confirm("Discard unsaved changes?")) return;
        if (window.showOpenFilePicker) {
            try {
                const [handle] = await window.showOpenFilePicker({ types: PICKER_TYPES });
                const file = await handle.getFile();
                if (loadText(await file.text(), file.name)) state.fileHandle = handle;
            } catch (err) {
                if (err.name !== "AbortError") status("Open failed: " + err.message, true);
            }
        } else {
            $("file-input").click();
        }
    }

    $("file-input").addEventListener("change", async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        if (loadText(await file.text(), file.name)) state.fileHandle = null;
        e.target.value = "";
    });

    function download(text, name) {
        const blob = new Blob([text], { type: "text/plain" });
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = name;
        a.click();
        setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    }

    async function writeTo(handle, text) {
        const w = await handle.createWritable();
        await w.write(text);
        await w.close();
    }

    async function save() {
        const text = LuaData.serialize(state.map);
        if (state.fileHandle) {
            try {
                await writeTo(state.fileHandle, text);
                state.dirty = false; updateTitle();
                status("Saved " + state.fileName);
                return;
            } catch (err) {
                status("Save failed (" + err.message + "); use Save as.", true);
                return;
            }
        }
        await saveAs();
    }

    async function saveAs() {
        const text = LuaData.serialize(state.map);
        if (window.showSaveFilePicker) {
            try {
                const handle = await window.showSaveFilePicker({ suggestedName: state.fileName, types: PICKER_TYPES });
                await writeTo(handle, text);
                state.fileHandle = handle;
                state.fileName = handle.name;
                state.dirty = false; updateTitle();
                status("Saved " + state.fileName);
            } catch (err) {
                if (err.name !== "AbortError") status("Save failed: " + err.message, true);
            }
        } else {
            download(text, state.fileName);
            state.dirty = false; updateTitle();
            status("Downloaded " + state.fileName + ". Move it into the game's maps/ folder.");
        }
    }

    function newMap() {
        if (state.dirty && !confirm("Discard unsaved changes?")) return;
        const w = Number(prompt("Width in tiles:", "100"));
        const h = Number(prompt("Height in tiles:", "100"));
        if (!(w > 0 && h > 0 && w <= 1000 && h <= 1000)) return;
        state.map = LuaData.blankMap(Math.round(w), Math.round(h));
        state.fileHandle = null;
        state.fileName = "newmap.lua";
        state.selected = null;
        state.dirty = true;
        undoStack.length = 0; redoStack.length = 0;
        ext = extents();
        state.camX = 0; state.camY = 0;
        updateTitle(); refreshPanels(); requestDraw();
    }

    window.addEventListener("beforeunload", (e) => {
        if (state.dirty) { e.preventDefault(); e.returnValue = ""; }
    });

    // ------------------------------------------------------------------
    // Wiring
    // ------------------------------------------------------------------

    $("btn-new").addEventListener("click", newMap);
    $("btn-open").addEventListener("click", openFile);
    $("btn-save").addEventListener("click", save);
    $("btn-saveas").addEventListener("click", saveAs);
    $("btn-undo").addEventListener("click", undo);
    $("btn-redo").addEventListener("click", redo);
    $("view-flat").addEventListener("click", () => setView("flat"));
    $("view-height").addEventListener("click", () => setView("height"));
    $("zoom-in").addEventListener("click", () => stepZoom(1));
    $("zoom-out").addEventListener("click", () => stepZoom(-1));
    document.querySelectorAll("[data-tool]").forEach(b => b.addEventListener("click", () => setTool(b.dataset.tool)));
    document.querySelectorAll("[data-brush]").forEach(b => b.addEventListener("click", () => setBrush(Number(b.dataset.brush))));
    for (const key of Object.keys(state.show)) {
        const cb = $("show-" + key);
        cb.checked = state.show[key];
        cb.addEventListener("change", () => { state.show[key] = cb.checked; requestDraw(); });
    }
    window.addEventListener("resize", resize);

    // Exposed for automated checks (and the browser console).
    window.editor = { state, loadText, serialize: () => LuaData.serialize(state.map), setView, setTool, setZoom, applyTool, beginStroke, endStroke, undo, redo, requestDraw };

    setTool("tile");
    setView("height");
    setBrush(1);
    resize();
    loadImages().then(() => {
        buildToolOptions();
        refreshPanels();
        updateTitle();
        status("Open a map (Ctrl+O), e.g. maps/map01.lua.");
        requestDraw();
    }).catch(err => status(err.message + " — keep this editor inside the game's tools/mapeditor folder.", true));
})();
