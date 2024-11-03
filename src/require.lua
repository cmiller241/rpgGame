function requireAll()
    require("src/window")   -- Handles window-related configurations (e.g., window dimensions, scaling)
    require("src/canvas")   -- Handles canvas management (e.g., creating and managing drawing surfaces for various game elements)
    require("src/player")   -- Player object and related functions (e.g., movement, animations, states)
    require("src/shader")   -- Loads all shaders (e.g., gradient, lighting, shadow, etc.)
    require("src/shadow")   -- Shadow object and related functions (e.g., shadow angle, size, frequency)
    require("src/sprites")  -- Loads and organizes all sprite images and quads (e.g., hero, grass, trees, etc.)
    require("src/mountain") -- Mountain object and related functions (e.g., drawing mountain tiles, handling elevation)
    require("src/tree")     -- Tree object and related functions (e.g., drawing tree tiles, handling elevation)
    require("src/grass")    -- Grass object and related functions (e.g., drawing grass tiles, handling elevation)
    require("src/tallgrass") -- Tall grass object and related functions
    -- Initialize the canvas after requiring window and canvas
    canvas:initialize(window.width, window.height)
end
