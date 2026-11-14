# Scattered Verses
This game is an attempt to create a Love2d RPG with custom made shaders. 

## Tasklist
- [x] Create topdown jump system for player
- [x] Create topdown platform system for z-index
- [x] Create shadow casting for sprites and elevated terrain
- [x] Create shadow casting from immediate light sources (fire, lamp, etc.)
- [x] Create shaders for subtly warping foilage and flora.
- [ ] Create water virtual screen to render over rest of the map
- [ ] Create mask system for player so he can swim
- [ ] Create hacky lighting and shadowing system

## Rendering & Lighting
Each frame is built in passes (see the top of `main.lua`):

1. **Surface map** (`src/terrain.lua`): one mesh draw records, for every screen pixel, whether it is a cliff face or a flat top and how high it is. From that, any pixel can be turned back into a 3D world point.
2. **Scene**: tiles go into one sprite batch. Sprites (player, trees, crops) go to the object canvas, and each queues its shadow.
3. **Sprite shadows** (`src/spriteShadow.lua`, `shaders/spriteShadowShader.glsl`): each sprite is treated as an upright cut-out facing the light, and the shadow is an exact ray/billboard intersection with no per-pixel loops. Shadows climb cliff faces.
4. **Lighting** (`src/lighting.lua`, `shaders/ultimateShader.glsl`): terrain shadows are ray-marched through a one-texel-per-tile heightmap, so their length depends on cliff height and sun altitude. Cliff faces are lit by sun direction, the lamp is occluded by terrain, and a time-of-day LUT is applied. On top of that:
   - **Ambient occlusion**: ground hemmed in by higher terrain (cliff bases, pit floors, bowls, under floating blocks) gets less sky light.
   - **Cloud shadows** (`src/clouds.lua`): a seamless noise layer drifts with the wind high above the ground; it shades terrain and sprites along the sun's direction, so the shadows shift with the time of day.
   - **Water reflections**: a reflected view ray is marched north from each water pixel; it shows the terrain it hits (and the player), or the sky.
   - **Page lights**: the Bible pages nearest the player light warm pools (blocked by terrain like the lamp), faint by day and full at night (`lighting.lua`).

**Slopes** (`src/terrain.lua`, SLOPES): neighbouring tiles less than 32 px apart are joined by a slope instead of a little cliff. Each tile is drawn through five points (four shared corners and its own height in the middle), its art is warped onto that shape (cached once per tile in `src/sprites.lua`), and a corner-map texture gives the shaders the exact sloped height for shadows plus the slope for sunlight. The player walks up and down slopes. Maps whose heights are all multiples of 32 have no slopes and draw exactly as before.

**Little touches of life** (`src/ambient.lua` ties them together): tall grass that sways, parts around the player and can be cut with the Hoe (`src/tallgrass.lua`); motes of light circling the Bible pages (`src/pagesparkles.lua`); dust from his footsteps (`src/dust.lua`); ripples and splashes in water (`src/splash.lua`); and fireflies at night (`src/fireflies.lua`). Glowing things (motes, fireflies) are drawn after lighting; the rest are sprites sorted with everything else.

Time of day lives in `src/sun.lua` (`sun.angle`: 0 = sunrise, 90 = noon, 180 = sunset, 180-360 = night). Press **C** in game to view the surface map; **M**/**N** scrub the time of day.

## Project Layout & Tools
- Every file in `src/` is a module: it returns a table, and other files `require` it. There are no shared globals.
- Maps are made with the map editor: open `tools/mapeditor/index.html` in Chrome or Edge (see `tools/mapeditor/README.md`). `maps/map01.lua` holds tiles, heights, floating blocks, starting water and objects (the player's spawn, Bible pages), and `src/level.lua` loads it for the game.
- `src/tiles.lua` defines every tile type: what is drawn on it, what sprite stands on it, and what part of it is solid. Add a tile type there.
- Maps: `love .` plays `maps/map01.lua`; `love . --map NAME` plays `maps/NAME.lua`. `maps/test.lua` is a fixed copy the dev tools and tests are built around (`--shots` and `--bench` use it automatically, `--test-map` picks it otherwise), so map01 can be edited freely.
- `love . --shots` renders a set of fixed scenes (sun angle, position, zoom) to PNGs plus a contact sheet. `love . --bench` prints the frame time for each scene. Both are defined in `src/devtools.lua` and write to the LÖVE save directory.
- Keys: arrows move, Space jumps, F uses a tool or picks up a page, Q / Shift+Q raise / lower the outlined tile (Ctrl+Q / Ctrl+Shift+Q in 8 px steps, which make slopes), W pours water on it, E places / removes a floating block over it (Hoe selected), A/S choose a toolbar slot, Z/X zoom, M/N scrub the time of day, C shows the surface map.

## Browser Version
The game also runs in a browser: `js/` is a JavaScript port of the Lua code, running on a small re-implementation of the LÖVE API (`js/love/`, from Asteroid Bob's web port) drawn with WebGL2.

```
npm install        # once (installs esbuild)
npm run build      # bundles js/boot.js -> dist/bundle.js
npm run serve      # static server on http://localhost:8080
```

Then open http://localhost:8080/index.html. `npm run watch` rebuilds on every save.

- `js/boot.js` preloads every image, sound, shader and font, then imports `js/main.js` (the port of `main.lua`). The browser can't load files synchronously the way LÖVE does, and the modules load their images as soon as they're imported. The list of files (`js/assetList.js`) is generated by `npm run assets`, which `build` and `watch` run for you. It scans `js/` for `'img/...'`, `'sound/...'`, `'shaders/...'` and `'font/...'` paths.
- Every `src/x.lua` has a matching `js/src/x.js`, and `spritemap.lua` matches `js/spritemap.js`. The `shaders/*.glsl` files are shared: both versions load the same files.
- The map is converted with `npm run maps` (`tools/lua-map-to-js.mjs`), which turns `maps/map01.lua` into `js/maps/map01.js` (the cell array plus the map's water and objects). Run it after saving a map in the editor.
- Differences from the Lua:
  - Arrays and tile coordinates are 0-based: Lua's `mapArray[row][col][1]` is `mapArray[row - 1][col - 1][0]`.
  - The quad lists (`sprites.spritesQuads`, `player.quads` and so on) and `toolbarMap.slots` keep the Lua's numbering from 1, because tile types, sprite numbers and tool numbers in the data refer to them by those numbers.
  - Functions that returned several values return an array.
- Dev tools go in the page's address instead of the command line: `index.html?shots` and `index.html?bench` (results are downloaded), and `index.html?scene=water_pools` starts in one of `devtools.js`'s scenes and keeps playing. The browser console has `__scatteredVerses` (player, terrain, water and more) for debugging.
- The old canvas JavaScript version is kept in `archive/js-canvas-old/`.

Changes made in the Lua code don't carry over to `js/` on their own; each one has to be made in both places.

Not ported yet: slopes, cloud shadows, water reflections and page lights. The shared shaders only use them when the Lua game sends their uniforms (`useCornerMap`, `cloudStrength`, `waterReflections`, `pageLightCount`), so the browser version still draws small height differences as steps and has none of those effects. Ambient occlusion works in both.
