tallGrass = {}

function tallGrass:add(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY, cameraX, cameraY)
    love.graphics.setCanvas(canvas.object)
    love.graphics.setShader(shader.grass)

    local distance2 = math.sqrt(math.pow(xTileWidthOffsetX - 10 - window.width/2, 2) 
        + math.pow(yTileHeightOffsetY - 40 + 27 - window.height/2, 2))
    
    if distance2 < 20 and (player.ax ~= 0 or player.ay ~= 0) then         
        if window.width / 2 > xTileWidthOffsetX - 10 then
            shader.grass:send("poop", 1.0)
        else
            shader.grass:send("poop", -1.0)
        end
    else 
        shader.grass:send("poop", 0.0)
    end 

    shader.grass:send("base", yTileHeightOffsetY - 40 + 27)
    love.graphics.draw(
        sprites.grass,
        sprites.grassQuad,
        xTileWidthOffsetX - 10,
        yTileHeightOffsetY - 40  
    )

    local distance1 = math.sqrt(math.pow(xTileWidthOffsetX - window.width / 2, 2) 
        + math.pow(yTileHeightOffsetY - 25 + 27 - window.height / 2, 2))
    if distance1 < 20 and (player.ax ~= 0 or player.ay ~= 0) then 
        if window.width / 2 > xTileWidthOffsetX then
            shader.grass:send("poop", 1.0)
        else
            shader.grass:send("poop", -1.0)
        end
    else 
        shader.grass:send("poop", 0.0)
    end 
    shader.grass:send("base", yTileHeightOffsetY - 25 + 27)
    shader.grass:send("time", love.timer.getTime())
    shader.grass:send("yTile", yC * sprites.size)
    love.graphics.draw(
        sprites.grass,
        sprites.grassQuad,
        xTileWidthOffsetX,
        yTileHeightOffsetY - 25    
    )

    love.graphics.setShader()
end