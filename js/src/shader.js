// shader.js
//
// Compiles every shader the game uses, once at startup. The .glsl files in
// shaders/ are shared with the LÖVE build (and preloaded for
// love.filesystem.read, see js/assetList.js).
//
// Shaders that need to understand the world's 3D shape (lighting and sprite
// shadows) get shaders/terrainCommon.glsl pasted in front of their own
// source, since GLSL in LÖVE has no #include.

import love from '../love/index.js';

const shader = {};
export default shader;

const terrainCommon = love.filesystem.read('shaders/terrainCommon.glsl');

function load(path, needsTerrain) {
  let source = love.filesystem.read(path);
  if (needsTerrain) {
    // Pixel stage only: it samples textures and is never needed by a
    // vertex stage (spriteShadowShader.glsl has one).
    source = '#ifdef PIXEL\n' + terrainCommon + '\n#endif\n' + source;
  }
  return love.graphics.newShader(source);
}

shader.ultimate      = load('shaders/ultimateShader.glsl', true);      // final lighting/composite pass
shader.spriteShadow  = load('shaders/spriteShadowShader.glsl', true);  // shadows cast by sprites
shader.surfaceDebug  = load('shaders/surfaceDebugShader.glsl');        // C key: show surface map
shader.windSway      = load('shaders/windSwayShader.glsl');            // tree canopy sway
shader.grass         = load('shaders/grassShader.glsl');               // tall grass sway
shader.outline       = load('shaders/outlineShader.glsl');             // highlight on pickups
shader.pixelScale    = load('shaders/pixelScaleShader.glsl');          // crisp upscaling to the window

// LÖVE throws an error if you send() a uniform that doesn't exist, and the
// GLSL compiler deletes uniforms the shader never reads. This sends only if
// the uniform survived compilation.
shader.sendIfPresent = function (s, name, ...values) {
  if (s.hasUniform(name)) {
    s.send(name, ...values);
  }
};
