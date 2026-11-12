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
