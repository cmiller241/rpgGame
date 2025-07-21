object = {}

function object:drawSingle(obj, cameraX, cameraY)
    -- Draw shadow
    if shadow.frame == shadow.frequency then
        love.graphics.setCanvas(canvas.shadow)
        love.graphics.setShader(shader.sprite)
        love.graphics.setBlendMode('lighten', 'premultiplied')
        shader.sprite:send("angle", shadow.angle)
        shader.sprite:send("colorMapCanvas", canvas.colorMap)
        shader.sprite:send("spriteHeight", 640.0)
        shader.sprite:send("spriteWidth", 640.0)
        shader.sprite:send("spriteBase", 60.0)
        shader.sprite:send("xstart", 10)
        shader.sprite:send("xend", 54)
        shader.sprite:send("shadowSize", 64)
        shader.sprite:send("opacity", 1.0)
        shader.sprite:send("canvasSize", {800, 600})
        shader.sprite:send("spotlight", {player.x + 8 - cameraX, player.y - cameraY + player.z / 2})
        shader.sprite:send("showSpotlight", 0)
        -- Sine wave animation: 1s period, 4-pixel amplitude
        local yOffset = math.sin(obj.animationTime * 2 * math.pi) * 4
        -- Dynamic divideBy based on yOffset
        shader.sprite:send("divideBy", -1 * yOffset / 32 + 2.5)
        love.graphics.draw(
            sprites.objects,
            sprites.biblePageCenter,
            obj.x - cameraX,
            obj.y - cameraY,
            0,
            1,
            1,
            0,
            0
        )
        love.graphics.setBlendMode('alpha')
        love.graphics.setShader()
    end

    -- Draw Bible page
    love.graphics.setCanvas(canvas.object)
    local yOffset = math.sin(obj.animationTime * 2 * math.pi) * 4
    love.graphics.draw(sprites.objects, sprites.biblePageCenter, obj.x - cameraX, obj.y - cameraY + yOffset)
end