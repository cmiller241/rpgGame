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
4. **Lighting** (`src/lighting.lua`, `shaders/ultimateShader.glsl`): terrain shadows are ray-marched through a one-texel-per-tile heightmap, so their length depends on cliff height and sun altitude. Cliff faces are lit by sun direction, the lamp is occluded by terrain, and a time-of-day LUT is applied.

Time of day lives in `src/sun.lua` (`sun.angle`: 0 = sunrise, 90 = noon, 180 = sunset, 180-360 = night). Press **C** in game to view the surface map; **M**/**N** scrub the time of day.

## Project Layout & Tools
- Every file in `src/` is a module: it returns a table, and other files `require` it. There are no shared globals.
- `src/tiles.lua` defines every tile type: what is drawn on it, what sprite stands on it, and what part of it is solid. Add a tile type there.
- `love . --shots` renders a set of fixed scenes (sun angle, position, zoom) to PNGs plus a contact sheet. `love . --bench` prints the frame time for each scene. Both are defined in `src/devtools.lua` and write to the LÖVE save directory.
- Keys: arrows move, Space jumps, F uses a tool or picks up a page, Q / Shift+Q raise / lower the outlined tile (Hoe selected), A/S choose a toolbar slot, Z/X zoom, M/N scrub the time of day, C shows the surface map.
