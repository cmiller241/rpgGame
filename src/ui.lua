-- ui.lua
ui = {}

ui.highlightedSlot = 1 -- Track the currently highlighted slot (1 to 10)
ui.slotScales = {} -- Current scale for each slot
ui.slotTargetScales = {} -- Target scale for each slot
ui.slotScaleTimers = {} -- Animation timers for each slot (0 to 1)
ui.animationDuration = 0.2 -- Animation duration for scaling
ui.isVisible = true -- Track if inventory is visible
ui.centerY = 0 -- Current vertical center position
ui.targetCenterY = 0 -- Target vertical center position
ui.centerYTimer = 1 -- Animation timer for centerY (0 to 1)
ui.slideDuration = 1 -- Animation duration for sliding
ui.baseSlotSize = 60 -- Base size of inventory slot sprite
ui.defaultScale = 2 -- Default scale factor
ui.highlightScaleFactor = 1.1 -- Highlighted slot scale multiplier
ui.appHeight = 0 -- Store appHeight
ui.highlightScale = 0 -- Store highlightScale

-- Initialize slot scales and timers
for i = 1, 10 do
    ui.slotScales[i] = ui.defaultScale -- Default scale
    ui.slotTargetScales[i] = ui.defaultScale -- Default target scale
    ui.slotScaleTimers[i] = 1 -- No animation initially
end
ui.slotTargetScales[1] = ui.defaultScale * ui.highlightScaleFactor -- Highlighted slot starts scaled up

function ui:drawInventory(appWidth, appHeight)
    if not self.isVisible and self.centerYTimer >= 1 then
        return -- Skip drawing if fully hidden
    end

    local baseSlotSize = self.baseSlotSize
    local defaultScale = self.defaultScale
    local numSlots = 10 -- Number of inventory slots
    local minMargin = 3 -- Minimum margin between slots
    local usableWidth = 0.6 * appWidth -- Inventory takes up 60% of screen width

    -- Calculate margin with default scale
    local highlightScaleFactor = self.highlightScaleFactor
    local scale = defaultScale
    local highlightScale = scale * highlightScaleFactor
    local slotSize = baseSlotSize * scale
    local highlightSlotSize = baseSlotSize * highlightScale
    local totalSlotWidth = (numSlots - 1) * slotSize + highlightSlotSize
    local margin = (usableWidth - totalSlotWidth) / (numSlots - 1)

    -- Adjust scale if margin is too small
    if margin < minMargin then
        scale = (usableWidth - (numSlots - 1) * minMargin) / (numSlots * baseSlotSize)
        highlightScale = scale * highlightScaleFactor
        slotSize = baseSlotSize * scale
        highlightSlotSize = baseSlotSize * highlightScale
        totalSlotWidth = (numSlots - 1) * slotSize + highlightSlotSize
        margin = minMargin
    end

    -- Store appHeight and highlightScale
    self.appHeight = appHeight
    self.highlightScale = highlightScale

    -- Update target scales for animation
    for i = 1, numSlots do
        self.slotTargetScales[i] = i == self.highlightedSlot and highlightScale or scale
    end

    -- Initialize centerY if not set
    if self.centerY == 0 then
        self.centerY = appHeight - baseSlotSize * highlightScale / 2 - 10
        self.targetCenterY = self.centerY
    end

    -- Starting x to center the inventory
    local totalWidthWithMargins = totalSlotWidth + (numSlots - 1) * margin
    local startX = (appWidth - totalWidthWithMargins) / 2

    local currentX = startX
    for i = 1, numSlots do
        local currentScale = self.slotScales[i]
        local slotSize = baseSlotSize * currentScale
        local ox = baseSlotSize / 2
        local oy = baseSlotSize / 2
        local drawX = currentX + slotSize / 2
        local drawY = self.centerY
        local alpha = i == self.highlightedSlot and 1.0 or 0.5
        love.graphics.setColor(1, 1, 1, alpha)
        -- Use the quad from visibleSlots
        local quadIndex = toolbarMap.visibleSlots[i]
        love.graphics.draw(sprites.toolbar, sprites.toolbarQuads[quadIndex], drawX, drawY, 0, currentScale, currentScale, ox, oy)
        currentX = currentX + slotSize + margin
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ui:update(dt)
    -- Update scaling animations
    for i = 1, 10 do
        local current = self.slotScales[i]
        local target = self.slotTargetScales[i]
        local diff = math.abs(current - target)

        if diff > 0.001 then
            self.slotScaleTimers[i] = math.min(self.slotScaleTimers[i] + dt / self.animationDuration, 1)
            local t = self.slotScaleTimers[i]
            local easedT = t * t * (3 - 2 * t) -- Smooth in-out easing
            self.slotScales[i] = current + (target - current) * easedT
        else
            self.slotScales[i] = target
            self.slotScaleTimers[i] = 1
        end
    end

    -- Update centerY animation
    if math.abs(self.centerY - self.targetCenterY) > 0.001 then
        self.centerYTimer = math.min(self.centerYTimer + dt / self.slideDuration, 1)
        local t = self.centerYTimer
        local easedT = t * t * (3 - 2 * t) -- Smooth in-out easing
        self.centerY = self.centerY + (self.targetCenterY - self.centerY) * easedT
    else
        self.centerY = self.targetCenterY
        self.centerYTimer = 1
    end
end

function ui:keypressed(key)
    local prevSlot = self.highlightedSlot
    if key == "a" then
        self.highlightedSlot = math.max(1, self.highlightedSlot - 1)
    elseif key == "s" then
        self.highlightedSlot = math.min(10, self.highlightedSlot + 1)
    elseif key == "r" then
        self.isVisible = not self.isVisible
        if self.isVisible then
            -- Show: animate back to original position
            self.targetCenterY = self.appHeight - self.baseSlotSize * self.highlightScale / 2 - 10
        else
            -- Hide: animate up 20 pixels, then down off-screen
            self.centerY = self.centerY - 20
            self.targetCenterY = self.appHeight + self.baseSlotSize * self.highlightScale / 2
        end
        self.centerYTimer = 0
    end

    if prevSlot ~= self.highlightedSlot then
        self.slotScaleTimers[prevSlot] = 0
        self.slotScaleTimers[self.highlightedSlot] = 0
    end
end