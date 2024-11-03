-- canvas.lua
canvas = {}

function canvas:initialize(cWidth, cHeight)
    -- Create canvases using the passed width and height
    print ("The cWidth is " .. cWidth )   
    canvas.object = love.graphics.newCanvas(cWidth, cHeight)
    canvas.shadow = love.graphics.newCanvas(cWidth, cHeight)
    canvas.colorMap = love.graphics.newCanvas(cWidth, cHeight)
    canvas.offscreen = love.graphics.newCanvas(cWidth, cHeight)
    canvas.intermediate = love.graphics.newCanvas(cWidth, cHeight)
    canvas.night = love.graphics.newCanvas(cWidth, cHeight)
    canvas.temp = love.graphics.newCanvas(200, 200)  -- This one has a fixed size

    canvas.showColorMap = false
    canvas.intermediate:setFilter("linear","nearest")
end

function canvas:clear()
    -- Clear all canvases
    love.graphics.setCanvas(canvas.object)
    love.graphics.clear(0,0,0,0)
    love.graphics.setCanvas(canvas.colorMap)
    love.graphics.clear(0,0,0,0)
    love.graphics.setCanvas(canvas.offscreen)
    love.graphics.clear(0,0,0,0)
    love.graphics.setCanvas(canvas.intermediate)
    love.graphics.clear(0,0,0,0)
    love.graphics.setCanvas(canvas.night)
    love.graphics.clear(0,0,0,0)
    love.graphics.setCanvas(canvas.temp)
    love.graphics.clear(0,0,0,0)
    love.graphics.setCanvas()
end