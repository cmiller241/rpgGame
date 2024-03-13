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

## Optimizing for Speed
- **spriteShader.glsl:** iterates through a loop to see if a coordinate would have a shadow cast from player on it. Despite a formula to check whether the coordinate, given the angle, would hit the base of the player, I still iterate through the loop afterward when I probably don't need to. 
- **lutShader.glsl:** does a conditional check of the angle to see what luts to use. I should probably do this outside the shader since conditional checks need to be made within effect() if the conditions are checked within the shader, and the checks are made for each pixel needlessly. I should just extern what LUTs to use. 
- **shadowShader.glsl:** If the shadows will never exceed 180 degrees, it seems reasonable to merge objectCanvas and shadowCanvas  