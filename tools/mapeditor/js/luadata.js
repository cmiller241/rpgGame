// luadata.js
//
// Reading and writing map files.
//
// Map files are Lua so the game can simply `require` them. They only ever
// contain DATA (tables, numbers, strings, booleans), so this file has a tiny
// parser for that subset of Lua, plus the code that converts between the
// file and the editor's in-memory map model.
//
// Works in the browser (as window.LuaData) and in Node (module.exports), so
// the same code can be used for one-off conversions from the command line.

(function (root) {
    "use strict";

    // ------------------------------------------------------------------
    // Tokenizer + parser for data-only Lua
    // ------------------------------------------------------------------

    // Splits Lua source into tokens: {t: "punct"|"name"|"number"|"string", v}.
    // Skips whitespace and comments (-- line and --[[ block ]]).
    function tokenize(src) {
        const tokens = [];
        let i = 0;
        const n = src.length;
        while (i < n) {
            const ch = src[i];
            if (/\s/.test(ch)) { i++; continue; }
            if (ch === "-" && src[i + 1] === "-") {
                const block = src.slice(i + 2).match(/^\[(=*)\[/);
                if (block) {
                    const close = "]" + block[1] + "]";
                    const end = src.indexOf(close, i);
                    i = end < 0 ? n : end + close.length;
                } else {
                    while (i < n && src[i] !== "\n") i++;
                }
                continue;
            }
            if (ch === '"' || ch === "'") {
                let s = "";
                i++;
                while (i < n && src[i] !== ch) {
                    if (src[i] === "\\") {
                        const e = src[i + 1];
                        if (e === "n") { s += "\n"; i += 2; }
                        else if (e === "t") { s += "\t"; i += 2; }
                        else if (e === "r") { s += "\r"; i += 2; }
                        else if (/[0-9]/.test(e)) {
                            const m = src.slice(i + 1).match(/^[0-9]{1,3}/)[0];
                            s += String.fromCharCode(parseInt(m, 10));
                            i += 1 + m.length;
                        } else { s += e; i += 2; }
                    } else { s += src[i]; i++; }
                }
                i++;
                tokens.push({ t: "string", v: s });
                continue;
            }
            const num = src.slice(i).match(/^-?(?:0x[0-9a-fA-F]+|[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)/);
            // A leading "-" is only part of a number where a value is expected.
            if (num && (ch !== "-" || isValueStart(tokens))) {
                tokens.push({ t: "number", v: Number(num[0]) });
                i += num[0].length;
                continue;
            }
            const name = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
            if (name) {
                tokens.push({ t: "name", v: name[0] });
                i += name[0].length;
                continue;
            }
            tokens.push({ t: "punct", v: ch });
            i++;
        }
        return tokens;
    }

    function isValueStart(tokens) {
        const last = tokens[tokens.length - 1];
        return !last || (last.t === "punct" && "{,=;[(".includes(last.v)) || (last.t === "name" && last.v === "return");
    }

    // Parses the first table constructor `{ ... }` in the source and returns
    // it as JS: a pure list becomes an Array, anything with named fields an
    // Object. Works for both "return { ... }" and the old
    // "local mapArray = { ... } return mapArray" files.
    function parseFirstTable(src) {
        const tokens = tokenize(src);
        let p = tokens.findIndex(tk => tk.t === "punct" && tk.v === "{");
        if (p < 0) throw new Error("No table found in file");

        function value() {
            const tk = tokens[p];
            if (!tk) throw new Error("Unexpected end of file");
            if (tk.t === "punct" && tk.v === "{") return table();
            p++;
            if (tk.t === "number" || tk.t === "string") return tk.v;
            if (tk.t === "name") {
                if (tk.v === "true") return true;
                if (tk.v === "false") return false;
                if (tk.v === "nil") return null;
            }
            throw new Error("Unexpected token '" + tk.v + "'");
        }

        function table() {
            p++; // {
            const arr = [];
            const obj = {};
            let named = false;
            while (!(tokens[p].t === "punct" && tokens[p].v === "}")) {
                const tk = tokens[p];
                if (tk.t === "name" && tokens[p + 1] && tokens[p + 1].v === "=") {
                    p += 2;
                    obj[tk.v] = value();
                    named = true;
                } else if (tk.t === "punct" && tk.v === "[") {
                    p++;
                    const key = value();
                    p++; // ]
                    p++; // =
                    obj[key] = value();
                    named = true;
                } else {
                    arr.push(value());
                }
                if (tokens[p].t === "punct" && (tokens[p].v === "," || tokens[p].v === ";")) p++;
            }
            p++; // }
            if (!named) return arr;
            arr.forEach((v, k) => { obj[k + 1] = v; });
            return obj;
        }

        return value();
    }

    // ------------------------------------------------------------------
    // Map model
    // ------------------------------------------------------------------
    //
    // In memory (0-based arrays, [row][col]):
    //   width, height, tileSize
    //   tiles[r][c]    tile type number (see TILE_TYPES)
    //   heights[r][c]  ground height in px, positive up
    //   blocks[r][c]   floating block underside in px, or null
    //   water[r][c]    starting water depth in px (0 = dry)
    //   objects[]      { type, x, y, ...properties } at world pixel positions
    //
    // In the file, blocks and water are sparse lists with 1-based
    // {col, row, value} entries, matching the game's tile coordinates.

    function blankMap(width, height) {
        const grid = (v) => Array.from({ length: height }, () => new Array(width).fill(v));
        return {
            format: 2, width, height, tileSize: 32,
            tiles: grid(1), heights: grid(0), blocks: grid(null), water: grid(0),
            objects: [{ type: "spawn", x: 100, y: 250 }],
        };
    }

    // Builds the model from a parsed file. Accepts the current format (2)
    // and the original mapArray format ({type, z, block} cells, z = -height).
    function modelFromData(data) {
        if (Array.isArray(data)) return modelFromLegacy(data);
        if (data.format !== 2) throw new Error("Unknown map format: " + data.format);
        const width = data.width, height = data.height;
        const m = blankMap(width, height);
        m.tileSize = data.tileSize || 32;
        for (let r = 0; r < height; r++) {
            for (let c = 0; c < width; c++) {
                m.tiles[r][c] = (data.tiles[r] && data.tiles[r][c] != null) ? data.tiles[r][c] : 1;
                m.heights[r][c] = (data.heights[r] && data.heights[r][c] != null) ? data.heights[r][c] : 0;
            }
        }
        for (const b of data.blocks || []) {
            if (inBounds(m, b[0] - 1, b[1] - 1)) m.blocks[b[1] - 1][b[0] - 1] = b[2];
        }
        for (const w of data.water || []) {
            if (inBounds(m, w[0] - 1, w[1] - 1)) m.water[w[1] - 1][w[0] - 1] = w[2];
        }
        m.objects = (data.objects || []).map(o => Object.assign({}, o));
        return m;
    }

    // Original format: mapArray[row][col] = {type, z, blockUnderside}. Rows
    // can be ragged (one row in map01 had 99 cells); short rows are padded
    // with flat grass.
    function modelFromLegacy(rows) {
        const height = rows.length;
        const width = rows.reduce((w, row) => Math.max(w, row.length), 0);
        const m = blankMap(width, height);
        for (let r = 0; r < height; r++) {
            for (let c = 0; c < width; c++) {
                const cell = rows[r][c];
                if (!cell) continue;
                m.tiles[r][c] = cell[0];
                m.heights[r][c] = -(cell[1] || 0) || 0;
                if (cell[2]) m.blocks[r][c] = cell[2];
            }
        }
        m.objects = [];   // the old format kept objects in code (src/objects.lua)
        m.legacy = true;
        return m;
    }

    function inBounds(m, c, r) {
        return r >= 0 && r < m.height && c >= 0 && c < m.width;
    }

    // ------------------------------------------------------------------
    // Writing
    // ------------------------------------------------------------------

    function luaString(s) {
        let out = '"';
        for (const ch of String(s)) {
            const code = ch.charCodeAt(0);
            if (ch === '"') out += '\\"';
            else if (ch === "\\") out += "\\\\";
            else if (ch === "\n") out += "\\n";
            else if (ch === "\r") out += "\\r";
            else if (ch === "\t") out += "\\t";
            else if (code < 32) out += "\\" + code;
            else out += ch;
        }
        return out + '"';
    }

    function luaNumber(v) {
        if (Number.isInteger(v)) return String(v);
        return String(Math.round(v * 1000) / 1000);
    }

    function luaValue(v) {
        if (typeof v === "number") return luaNumber(v);
        if (typeof v === "boolean") return v ? "true" : "false";
        if (v === null || v === undefined) return "nil";
        return luaString(v);
    }

    function luaKey(k) {
        return /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : "[" + luaString(k) + "]";
    }

    // Writes the model as a format-2 Lua map file.
    function serialize(m) {
        const L = [];
        L.push("-- Scattered Verses map (format 2). Written by tools/mapeditor; safe to edit by hand.");
        L.push("--");
        L.push("-- tiles[row][col]    tile type: 1 grass, 10 tall grass, 56 dirt, 72-87 crops");
        L.push("--                    (even = dry, odd = watered), 512 oak tree, 520 pine tree");
        L.push("-- heights[row][col]  ground height in px, positive up (64 = two-tile cliff, -32 = pit)");
        L.push("-- blocks             floating blocks: {col, row, underside height px}");
        L.push("-- water              water at the start: {col, row, depth px}");
        L.push("-- objects            things at pixel positions: {type = ..., x = ..., y = ..., ...}");
        L.push("--                    (\"spawn\" = player start, \"page\" = Bible page; x, y = feet / base)");
        L.push("return {");
        L.push("    format = 2,");
        L.push("    width = " + m.width + ",");
        L.push("    height = " + m.height + ",");
        L.push("    tileSize = " + m.tileSize + ",");
        L.push("");
        L.push("    tiles = {");
        for (const row of m.tiles) L.push("        {" + row.join(",") + "},");
        L.push("    },");
        L.push("");
        L.push("    heights = {");
        for (const row of m.heights) L.push("        {" + row.map(luaNumber).join(",") + "},");
        L.push("    },");
        L.push("");
        L.push("    blocks = {");
        for (let r = 0; r < m.height; r++) for (let c = 0; c < m.width; c++) {
            if (m.blocks[r][c] != null) L.push("        {" + (c + 1) + ", " + (r + 1) + ", " + luaNumber(m.blocks[r][c]) + "},");
        }
        L.push("    },");
        L.push("");
        L.push("    water = {");
        for (let r = 0; r < m.height; r++) for (let c = 0; c < m.width; c++) {
            if (m.water[r][c] > 0) L.push("        {" + (c + 1) + ", " + (r + 1) + ", " + luaNumber(m.water[r][c]) + "},");
        }
        L.push("    },");
        L.push("");
        L.push("    objects = {");
        for (const o of m.objects) {
            const keys = Object.keys(o).filter(k => !["type", "x", "y"].includes(k)).sort();
            const parts = ["type = " + luaValue(o.type), "x = " + luaNumber(o.x), "y = " + luaNumber(o.y)]
                .concat(keys.map(k => luaKey(k) + " = " + luaValue(o[k])));
            L.push("        { " + parts.join(", ") + " },");
        }
        L.push("    },");
        L.push("}");
        return L.join("\n") + "\n";
    }

    function parseMapFile(text) {
        return modelFromData(parseFirstTable(text));
    }

    const api = { tokenize, parseFirstTable, parseMapFile, serialize, blankMap, modelFromData };
    if (typeof module !== "undefined" && module.exports) module.exports = api;
    else root.LuaData = api;
})(typeof window !== "undefined" ? window : this);
