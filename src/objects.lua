-- objects.lua
object = {}

-- Define the objects array
object.objects = {
    {
        x = 200, 
        y = 250, 
        animationTime = 0, 
        message = "Remember this: Whoever sows sparingly will also reap sparingly, and whoever sows generously will also reap generously. Each of you should give what you have decided in your heart to give, not reluctantly or under compulsion, for God loves a cheerful giver.", 
        verse = "2 Corinthians 9:6-7", 
        tool = 4,
        toolMessage = "You can now use a hoe. Dig up earth and plant seeds!"
    },
    {
        x = 800, 
        y = 450, 
        animationTime = 0, 
        message = "Through thy precepts I get understanding: therefore I hate every false way. Thy Word is a lamp unto my feet and a light unto my path", 
        verse = "Psalm 119:104,105", 
        tool = 3,
        toolMessage = "You can now use a lamp. It will make your path easier at night and in caves!"
    },
    {
        x = 300, 
        y = 450, 
        animationTime = 0, 
        message = "The Lord will guide you always; he will satisfy your needs in a sun-scorched land and will strengthen your frame. You will be like a well-watered garden, like a spring whose waters never fail.", 
        verse = "Isaiah 58:11", 
        tool = 9,
        toolMessage = "You can now use a watering can. This will allow you to water the seeds you plant in order to help them grow!"
    },
    {
        x = 300, 
        y = 650, 
        animationTime = 0, 
        message = "For, 'All people are like grass, and all their glory is like the flowers of the field; the grass withers and the flowers fall, but the word of the Lord endures forever.' And this is the word that was preached to you.", 
        verse = "1 Peter 1:24-25", 
        tool = 10,
        toolMessage = "You can now plant grass!"
    }
}

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
end

function object:removeNearest(playerX, playerY)
    local nearestIndex, minDistance = nil, math.huge
    for i, obj in ipairs(self.objects) do
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
        table.remove(self.objects, nearestIndex)
    end
end