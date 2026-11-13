# Map Editor

A browser tool for editing `maps/*.lua`. Open `tools/mapeditor/index.html` in
Chrome or Edge. Nothing needs to be installed or built.

- **Open** (Ctrl+O) a map such as `maps/map01.lua`, edit it, then **Save** (Ctrl+S).
  Chrome and Edge save back into the same file. Other browsers download the
  saved file instead, and you copy it into `maps/` yourself.
- The editor loads its art from `../../img/`, so keep it in this folder.
- After saving, run `npm run maps` if you use the web build. The LÖVE game
  reads the `.lua` file directly.

## Views

- **Flat** (Tab toggles): a top-down grid. Each tile is tinted by its height
  (`+2` = two tiles up, `-1` = a pit one tile deep). Floating blocks show their
  underside (`B24`), and water shows as blue.
- **Height**: the map drawn the way the game draws it, with cliff faces, pits,
  trees, crops, blocks and objects. It has no lighting.

The checkboxes in the toolbar show or hide the grid, height labels, water,
blocks and objects.

## Tools

| Key | Tool    | Left click                         | Right click            |
|-----|---------|------------------------------------|------------------------|
| 1   | Tile    | paint the chosen tile type         | paint plain grass      |
| 2   | Height  | raise / lower / set to a value     | the opposite           |
| 3   | Block   | place a floating block (underside) | remove it              |
| 4   | Water   | add / set water depth              | remove water           |
| 5   | Objects | select, drag, or add an object     | delete the object      |

- **Alt+click** picks up the value under the cursor (tile type, height, block
  underside or water depth) for the current tool.
- **[ ]** change the brush (1×1, 3×3, 5×5). Wheel zooms, middle-drag or
  Space+drag pans, and Ctrl+Z / Ctrl+Y undo and redo.
- Trees (512 oak, 520 pine) are tiles. The editor draws the sprite offset from
  its base the same way the game does, so the trunk sits on the tile you painted.
- Objects sit at pixel positions (their feet or base), not on tiles. The
  panel on the right edits their properties: `type`, `x`, `y`, plus any others
  (a page has `verse`, `message`, `tool` and `toolMessage`). Use **+ Property**
  to add fields for new kinds of object, such as an NPC's `name` or `dialog`.
  A map has one `spawn`, which is where the player starts.

## File format (format 2)

A map is a Lua file that returns a table. The editor writes it, but it is
meant to be readable and safe to edit by hand.

```lua
return {
    format = 2, width = 100, height = 99, tileSize = 32,
    tiles   = { {1,1,512,...}, ... },  -- tiles[row][col]: tile type
    heights = { {0,0,32,...}, ... },   -- heights[row][col]: px, positive up, negative = pit
    blocks  = { {12, 30, 24}, ... },   -- floating blocks: {col, row, underside px}
    water   = { {40, 18, 12}, ... },   -- starting water: {col, row, depth px}
    objects = {
        { type = "spawn", x = 100, y = 250 },
        { type = "page", x = 200, y = 250, verse = "...", message = "...", tool = 4, toolMessage = "..." },
    },
}
```

Rows and columns are 1-based, as in Lua. Water is a sparse list rather than a
full grid: most tiles are dry, and the list only sets the starting water. After
that, the game's water simulation takes over.

`src/level.lua` loads the file for the game. `tools/lua-map-to-js.mjs` converts
it for the web build, using this editor's parser (`js/luadata.js`).

## Code

- `js/luadata.js`: reads Lua data files (the old `{type, z, block}` cell maps
  as well as format 2), plus the editor's map model and the serializer.
- `js/render.js`: draws both views. Grass, dirt, flourishes and cliff walls are
  ported from the game's `src/grass.lua`, `src/dirt.lua` and `src/mountain.lua`.
- `js/editor.js`: tools, undo/redo, panels, input and file handling.
