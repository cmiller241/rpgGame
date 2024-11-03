tree = {}

function tree:add(xC, yC, z, zHeight, xTileWidthOffsetX, yTileHeightOffsetY, cameraX, cameraY)
    local time = love.timer.getTime()
    local sway = math.sin(time + yC) * 0.04

    if shadow.frame == shadow.frequency then
        love.graphics.setShader(shader.sprite)
        love.graphics.setBlendMode('lighten', 'premultiplied')
        shader.sprite:send("divideBy", 1)
        shader.sprite:send("angle", shadow.angle)
        shader.sprite:send("colorMapCanvas", canvas.colorMap)
        shader.sprite:send("spriteLeftX", xTileWidthOffsetX + sprites.size / 2 - 480/2)
        shader.sprite:send("spriteTopY", yTileHeightOffsetY - 224)
        shader.sprite:send("spriteHeight", 480.0)
        shader.sprite:send("spriteWidth",1440.0)
        shader.sprite:send("spriteBase", 250)
        shader.sprite:send("xstart", 193)
        shader.sprite:send("xend", 320)
        shader.sprite:send("shadowSize",250)
        shader.sprite:send("opacity", 1.0)
        shader.sprite:send("canvasSize", {800, 600})
        shader.sprite:send("spotlight", {player.x + 8 - cameraX, player.y - cameraY + player.z / 2})

        --Calculate distance between spotlight and tree trunk
        local dx = (player.x + 8 - cameraX) - xTileWidthOffsetX
        local dy = (player.y - cameraY + player.z / 2) - yTileHeightOffsetY
        local distance = math.sqrt(dx * dx + dy * dy)

        --Set the noSunShadows uniform based on the angle
        if (shadow.angle % 360 > 180 and shadow.angle % 360 < 360) then
            shader.sprite:send("noSunShadows",1.0)
        else 
            shader.sprite:send("noSunShadows",0.0)
        end

        -- Set the showSpotlight uniform based on the distance
        if distance < 100 then                                  --200 represents the radius of the spotlight
            shader.sprite:send("showSpotlight", 1)
        else
            shader.sprite:send("showSpotlight", 0)
        end

        love.graphics.setCanvas(canvas.shadow)
        love.graphics.draw(             --Draw the trunk shadow
            sprites.tree,
            sprites.treeTrunk,
            xTileWidthOffsetX,
            yTileHeightOffsetY,
            sway,
            1,
            1,
            224,
            224        
        )

        shader.sprite:send("xstart",150)
        shader.sprite:send("xend",350)
        love.graphics.draw(             --Draw the tree leaves shadow
            sprites.tree,
            sprites.treeFoliage,
            xTileWidthOffsetX,
            yTileHeightOffsetY,
            sway,
            1,
            1,
            224,
            224        
        )

        love.graphics.setBlendMode('alpha')
        love.graphics.setShader()
    end

    love.graphics.setShader()
    love.graphics.setCanvas(canvas.object)
    love.graphics.draw(        --Draw the tree trunk
        sprites.tree,
        sprites.treeTrunk,
        xTileWidthOffsetX,
        yTileHeightOffsetY,
        sway,
        1,
        1,
        224,
        224
    )

    love.graphics.draw(        --Draw the tree leaves
        sprites.tree,
        sprites.treeFoliage,
        xTileWidthOffsetX,
        yTileHeightOffsetY,
        sway,
        1,
        1,
        224,
        224
    )
    love.graphics.setShader()
end