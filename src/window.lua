-- window.lua
--
-- Size of the GAME VIEW in art pixels: how much of the world is rendered
-- each frame, before it's scaled up to fill the real window.
--
-- These are only starting values. view.lua sets them from the zoom level and
-- the real window size (e.g. a 1280x800 window at 2x zoom = 640x400) and
-- rebuilds the canvases whenever they change.

window = {}

window.width = 800
window.height = 600
