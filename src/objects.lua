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
            obj.x - 32 - cameraX,
            obj.y - 64 - cameraY,
            0,
            1,
            1,
            0,
            0
        )
        love.graphics.setBlendMode('alpha')
        love.graphics.setShader()
    end

    -- Draw Bible page with outline shader if player is near and facing it
    love.graphics.setCanvas(canvas.object)
    local yOffset = math.sin(obj.animationTime * 2 * math.pi) * 4
    -- Calculate distance between player position and Bible page position
    local dx = player.x - obj.x
    local dy = player.y - obj.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local isFacing = false
    if player.direction == "Up" and dy > 0 then
        isFacing = true
    elseif player.direction == "Down" and dy < 0 then
        isFacing = true
    elseif player.direction == "Left" and dx > 0 then
        isFacing = true
    elseif player.direction == "Right" and dx < 0 then
        isFacing = true
    end
    if distance < 50 and isFacing then
        -- Apply outline shader and set player flag
        love.graphics.setShader(shader.outline)
        player.isNearOutlinedObject = true
    end
    love.graphics.draw(sprites.objects, sprites.biblePageCenter, obj.x - 32 - cameraX, obj.y - 64 - cameraY + yOffset)
    love.graphics.setShader()

    -- Draw debug circles for player and object coordinates
    -- love.graphics.setCanvas(canvas.object)
    -- -- Red circle for player position (player.x, player.y)
    -- love.graphics.setColor(1, 0, 0, 1) -- Red
    -- love.graphics.circle("fill", player.x - cameraX, player.y - cameraY, 5)
    -- -- Yellow circle for object position (obj.x, obj.y)
    -- love.graphics.setColor(1, 1, 0, 1) -- Yellow
    -- love.graphics.circle("fill", obj.x - cameraX, obj.y - cameraY, 5)
    -- love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

function object:removeNearest(playerX, playerY)
    local nearestIndex, minDistance = nil, math.huge
    for i, obj in ipairs(objects) do
        local dx = playerX - obj.x
        local dy = playerY - obj.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local isFacing = false
        if player.direction == "Up" and dy > 0 then
            isFacing = true
        elseif player.direction == "Down" and dy < 0 then
            isFacing = true
        elseif player.direction == "Left" and dx > 0 then
            isFacing = true
        elseif player.direction == "Right" and dx < 0 then
            isFacing = true
        end
        if distance < 50 and isFacing and distance < minDistance then
            minDistance = distance
            nearestIndex = i
        end
    end
    if nearestIndex then
        table.remove(objects, nearestIndex)
    end
end