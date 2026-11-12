function requireAll()
    -- Load toolbarMap first to ensure it's available for player and ui
    local success, result = pcall(function() return require("src/toolbarMap") end)
    if success then
        toolbarMap = result
        print("toolbarMap loaded successfully: ", toolbarMap ~= nil)
    else
        print("Error loading src/toolbarMap: ", result)
    end

    require("src/window")       -- Game view size (window.width/height) and scaling
    require("src/canvas")       -- Off-screen render targets
    require("src/view")         -- Zoom levels and scaling the frame to the window
    require("src/player")       -- Player movement, animation, tools
    require("src/shader")       -- Compiles all shaders
    require("src/sun")          -- Time of day: sun direction, shadow length/strength, LUT blend
    require("src/sprites")      -- Images, quads and the tile sprite batch
    require("src/terrain")      -- Heightmap + surface map used for lighting and shadows
    require("src/spriteShadow") -- Queues and renders shadows cast by sprites
    require("src/lighting")     -- Lamp state and the final lighting/composite pass
    require("src/mountain")     -- Cliff-face tile sprites
    require("src/tree")         -- Trees (draw + shadow)
    require("src/crop")         -- Crops (draw + shadow)
    require("src/grass")        -- Grass tiles and decorations
    require("src/tallgrass")    -- Tall grass
    require("src/dirt")         -- Plowed dirt tiles
    require("src/ui")           -- UI elements (e.g., inventory)
    require("src/sounds")       -- Loading sounds
    require("src/objects")      -- Collectible Bible pages
    require("src/message")      -- Message box
    require("src/map")          -- xorshift16 used for crop growth

    canvas:initialize(window.width, window.height)
    terrain:build(mapArray)
    grass:buildFlourishes()
end
