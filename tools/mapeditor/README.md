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
blocks and objects, and turn slopes on or off.

## Slopes

Neighbouring tiles whose heights differ by **less than 32 px** are joined by a
slope instead of a small cliff: the ground slants from one to the other.
Differences of 32 px or more stay cliffs with walls, so maps built from whole
tiles look exactly as before.

- Set the Height tool's step to 8 or 16 px and raise tiles a little at a time
  to make hills, ramps and bowls. For example, 0, 8, 16, 24, 32 across five
  tiles is a ramp up one tile.
- Each corner of a tile is the average height of the joined tiles that share
  it, so slopes have no seams, and the middle of the tile is at its own
  height, so a single raised tile becomes a small peak. The tile's art is
  warped to fit (one pixel column at a time, so it stays crisp), and slopes
  get light from the upper left and shade on the far side.
- A ramp next to lower, unjoined ground still shows a cliff on that side.
  For example, a ramp up to a plateau has walls on both sides.
- The game draws, lights and walks on slopes the same way (`src/terrain.lua`,
  SLOPES). In the game, Ctrl+Q / Ctrl+Shift+Q raise and lower a tile by 8 px.
  The browser build (`js/`) doesn't have slopes yet.

## Tools

| Key | Tool    | Left click                         | Right click            |
|-----|---------|------------------------------------|------------------------|
| 1   | Tile    | paint the chosen tile type         | paint plain grass      |
| 2   | Height  | raise / lower / set to a value     | the opposite           |
| 3   | Block   | place a floating block (underside) | remove it              |
| 4   | Water   | add / set water depth              | remove water           |
| 5   | Objects | select, drag, or add an object     | delete the object      |
| 6   | Ridge   | drag out a ridge                   | drag out a valley      |
| 7   | Smooth  | soften heights under the brush     | level the brush area   |

- **Ridge** (6): drag from one end to the other to raise a long ridge. Its
  height climbs to a peak and back down along the drag, in 8 px steps (so
  you can walk up it), and it's flat across its width, so its long sides are
  cliff faces wherever it's 32 px or more high. Options: width (tiles), peak
  height, where the peak is along the drag, and the profile (Peak: straight
  up to a point; Rounded: a smooth hump; Plateau: climbs, runs flat,
  descends). It only ever raises ground, so ridges can cross or run into
  hills; right-drag cuts a valley of the same shape. The preview while
  dragging is the real thing, and the whole ridge is one undo step.
- **Smooth** (7): each tile under the brush moves toward the average height
  of its 3x3 neighbourhood (Gentle: halfway, Full: all the way), turning
  cliffs into slopes and evening out bumps; click again to smooth more.
  Right-drag levels the brush area to its average height. Use the brush
  size (1x1, 3x3, 5x5) for the area.
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
