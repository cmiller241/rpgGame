-- objects.lua
local object = {}
package.loaded[...] = object  -- register now, so modules that require each other share this table

local canvas = require("src.canvas")
local player = require("src.player")
local shader = require("src.shader")
local spriteShadow = require("src.spriteShadow")
local sprites = require("src.sprites")
local terrain = require("src.terrain")
local level = require("src.level")

-- The Bible pages placed on the map: every "page" object in the map file
-- (edit them in tools/mapeditor). Each has x, y (where it stands), verse,
-- message, tool (toolbar slot it unlocks) and toolMessage.
object.objects = level:objectsOfType("page")
for _, page in ipairs(object.objects) do
    page.animationTime = 0   -- drives the bobbing
end

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
