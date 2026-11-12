-- objects.lua
local object = {}
package.loaded[...] = object  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local player = require("src.player")
local shader = require("src.shader")
local spriteShadow = require("src.spriteShadow")
local sprites = require("src.sprites")
local terrain = require("src.terrain")

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

-- How close (px) the player must be to pick a page up.
object.reach = 50

-- The nearest page within reach that the player is facing, or nil.
-- "Facing" means the page is on the side he's looking toward.
function object:findFacing(p)
    local best, bestDist = nil, self.reach
    for _, obj in ipairs(self.objects) do
        local dx, dy = obj.x - p.x, obj.y - p.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local facing = (p.direction == "Up" and dy < 0) or (p.direction == "Down" and dy > 0)
                    or (p.direction == "Left" and dx < 0) or (p.direction == "Right" and dx > 0)
        if facing and dist < bestDist then
            best, bestDist = obj, dist
        end
    end
    return best
end

function object:remove(obj)
    for i, o in ipairs(self.objects) do
        if o == obj then
            table.remove(self.objects, i)
            return
        end
    end
end

-- Map row (1-based) a page belongs to for draw ordering: the row its
-- ground point is in.
function object:rowOf(obj)
    return math.floor((obj.y - 4) / sprites.size) + 1
end

-- Called while building the scene (see main.lua). Queues the page's shadow
-- and adds a draw item. The 64x64 sprite is drawn with its bottom-centre at
-- (obj.x, obj.y), bobbing up and down.
function object:addSprites(list, obj, cameraX, cameraY)
    local groundX, groundY = obj.x, obj.y - 4
    local groundH = terrain:heightAtWorld(groundX, groundY)
    -- Bob up and down: 1 s period, 4 px amplitude.
    local yOffset = math.sin(obj.animationTime * 2 * math.pi) * 4

    -- Its bottom row (60) hovers 4 px above the ground at rest.
    local qx, qy, qw, qh = sprites.biblePageCenter:getViewport()
    local caster = {
        image = sprites.objects, data = sprites.objectsData,
        quadX = qx, quadY = qy, quadW = qw, quadH = qh,
        anchorX = 32, anchorY = 60,
        worldX = groundX, worldY = groundY, worldZ = groundH,
        lift = 4 - yOffset,
    }
    spriteShadow:add(caster)

    list[#list + 1] = {
        owner = self, caster = caster, obj = obj,
        sortY = groundY - cameraY, sortX = groundX - cameraX,
        drawX = obj.x - 32 - cameraX, drawY = obj.y - 64 - cameraY + yOffset - groundH,
        tintX = groundX, tintY = groundY, tintZ = groundH + 30,
    }
end

-- Draws a page item, outlined if it's the one the player can pick up.
function object:drawItem(item, tint)
    love.graphics.setCanvas(canvas.object)
    if item.obj == player.facingPage then
        love.graphics.setShader(shader.outline)
    end
    love.graphics.setColor(tint, tint, tint, 1)
    love.graphics.draw(sprites.objects, sprites.biblePageCenter, item.drawX, item.drawY)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader()
end

return object
