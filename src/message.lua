-- message.lua
message = {}

customFont = love.graphics.newFont("font/EightBitDragon-anqx.ttf", 24) -- Increased font size to 24 pixels
message.isActive = false -- Whether a message box is displayed
message.text = "" -- Stored message from picked-up object
message.verse = "" -- Stored verse reference (book and verse)
message.displayedText = "" -- Currently displayed text (built character by character)
message.charIndex = 0 -- Current character index for typing
message.typingTimer = 0 -- Timer for typing speed
message.typingSpeed = 0.00 -- Time per character in seconds (adjust for speed)
message.displayTimer = 0 -- Timer for displaying the parchment
message.tool = nil -- Stored tool quad index from picked-up object
message.toolMessage = "" -- Stored tool message from picked-up object
message.displayedToolText = "" -- Currently displayed tool message
message.toolCharIndex = 0 -- Current character index for tool message typing
message.toolTypingTimer = 0 -- Timer for tool message typing
message.toolTypingSpeed = 0.02 -- Time per character for tool message

function message:show()
    self.isActive = true
    self.displayedText = "" -- Reset displayed text
    self.charIndex = 0 -- Reset character index
    self.typingTimer = 0 -- Reset timer
    self.displayTimer = 0 -- Reset display timer
    self.displayedToolText = "" -- Reset displayed tool text
    self.toolCharIndex = 0 -- Reset tool character index
    self.toolTypingTimer = 0 -- Reset tool typing timer
end

function message:hide()
    if self.tool then
        for i = 1, 10 do
            if toolbarMap.visibleSlots[i] == 1 then
                toolbarMap.visibleSlots[i] = self.tool
                break
            end
        end
    end
    self.isActive = false
    self.text = "" -- Clear message
    self.verse = "" -- Clear verse
    self.tool = nil -- Clear tool
    self.toolMessage = "" -- Clear tool message
    -- Reset player state to Standing
    player.state = "Standing"
    player.frame = 1
    player.frameTime = 0
end

function message:update(dt)
    if not self.isActive then return end
    self.displayTimer = self.displayTimer + dt -- Increment display timer

    -- Update parchment text typing
    if self.typingSpeed == 0 then
        self.charIndex = string.len(self.text)
        self.displayedText = self.text
    elseif self.charIndex < string.len(self.text) then
        self.typingTimer = self.typingTimer + dt
        if self.typingTimer >= self.typingSpeed then
            self.charIndex = self.charIndex + 1
            self.displayedText = string.sub(self.text, 1, self.charIndex)
            self.typingTimer = 0
        end
    end

    -- Update tool message typing (only when textbox is visible)
    if self.displayTimer >= 1 then
        if self.toolTypingSpeed == 0 then
            self.toolCharIndex = string.len(self.toolMessage)
            self.displayedToolText = self.toolMessage
        elseif self.toolCharIndex < string.len(self.toolMessage) then
            self.toolTypingTimer = self.toolTypingTimer + dt
            if self.toolTypingTimer >= self.toolTypingSpeed then
                self.toolCharIndex = self.toolCharIndex + 1
                self.displayedToolText = string.sub(self.toolMessage, 1, self.toolCharIndex)
                self.toolTypingTimer = 0
            end
        end
    end
end

-- Helper function to split text into lines
function message:splitText(text, font, maxWidth)
    local lines = {}
    local currentLine = ""
    local spaceWidth = font:getWidth(" ")
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    local wordIndex = 1
    local lineWidth = 0

    while wordIndex <= #words do
        local word = words[wordIndex]
        local wordWidth = font:getWidth(word)

        if lineWidth + wordWidth <= maxWidth then
            currentLine = currentLine .. (currentLine == "" and word or " " .. word)
            lineWidth = lineWidth + wordWidth + (currentLine == word and 0 or spaceWidth)
            wordIndex = wordIndex + 1
        else
            if currentLine ~= "" then
                table.insert(lines, currentLine)
                currentLine = ""
                lineWidth = 0
            else
                -- Word is too long for one line; split it
                local chars = {}
                for char in word:gmatch(".") do
                    table.insert(chars, char)
                end
                local partialWord = ""
                local partialWidth = 0
                for i, char in ipairs(chars) do
                    local charWidth = font:getWidth(char)
                    if partialWidth + charWidth <= maxWidth then
                        partialWord = partialWord .. char
                        partialWidth = partialWidth + charWidth
                    else
                        table.insert(lines, partialWord)
                        partialWord = char
                        partialWidth = charWidth
                    end
                end
                if partialWord ~= "" then
                    currentLine = partialWord
                    lineWidth = partialWidth
                end
                wordIndex = wordIndex + 1
            end
        end
    end
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    return lines
end

function message:draw(appWidth, appHeight)
    if not self.isActive then return end
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw parchment centered at screen's horizontal center, 20 pixels from top
    local parchmentWidth = sprites.parchment:getWidth()
    local maxWidth = 0.8 * appWidth
    local parchmentScale = math.min(1.0, maxWidth / parchmentWidth)
    local scaledParchmentWidth = parchmentWidth * parchmentScale
    local parchmentX = appWidth / 2 - scaledParchmentWidth / 2
    local parchmentY = 20
    love.graphics.draw(sprites.parchment, parchmentX, parchmentY, 0, parchmentScale, parchmentScale)

    -- Draw textbox at bottom center after 1 second, at least 80% of screen width
    if self.displayTimer >= 1 then
        local textboxWidth = sprites.textbox:getWidth()
        local textboxHeight = sprites.textbox:getHeight()
        local textboxScale = math.max(maxWidth / textboxWidth, 0.8 * appWidth / textboxWidth)
        local scaledTextboxWidth = textboxWidth * textboxScale
        local scaledTextboxHeight = textboxHeight * textboxScale
        local textboxX = appWidth / 2 - scaledTextboxWidth / 2
        local textboxY = appHeight - 20 - scaledTextboxHeight
        love.graphics.draw(sprites.textbox, textboxX, textboxY, 0, textboxScale, textboxScale)

        -- Draw the toolbar sprite quad and tool message if set
        if self.tool then
            local padding = 30 * textboxScale -- Increased padding for icon and text
            local iconBaseSize = 60 -- Assuming base size of toolbar quads is 60x60
            local iconScale = (scaledTextboxHeight - 2 * padding) / iconBaseSize
            local iconSize = iconBaseSize * iconScale
            local iconX = textboxX + padding
            local iconY = textboxY + (scaledTextboxHeight - iconSize) / 2
            love.graphics.draw(sprites.toolbar, sprites.toolbarQuads[self.tool], iconX, iconY, 0, iconScale, iconScale)

            -- Draw tool message to the right of the icon
            if self.toolMessage then
                local dynamicFont = love.graphics.newFont("font/EightBitDragon-anqx.ttf", math.floor(math.max(20 * appWidth / 1280, 16)))
                love.graphics.setFont(dynamicFont)
                love.graphics.setColor(1, 1, 1, 1) -- White text for toolMessage
                local textX = iconX + iconSize + 20 * textboxScale -- Increased margin to 20px from icon
                local textY = textboxY + padding -- 20px padding from top
                local textWidth = scaledTextboxWidth - (textX - textboxX) - padding -- Remaining width minus right padding
                local lineHeight = dynamicFont:getHeight() * 1.5
                local lines = self:splitText(self.displayedToolText, dynamicFont, textWidth)
                for i, line in ipairs(lines) do
                    love.graphics.print(line, textX, textY + (i - 1) * lineHeight)
                end
            end
        end
    end

    -- Dynamic font size based on appWidth
    local baseFontSize = 20
    local fontSizeFactor = appWidth / 1280 -- Relative to base width of 1280 pixels
    local fontSize = math.floor(math.max(baseFontSize * fontSizeFactor, 16)) -- Clamp at minimum 16
    local dynamicFont = love.graphics.newFont("font/EightBitDragon-anqx.ttf", fontSize)

    -- Verse font (slightly bigger)
    local verseFontSize = math.floor(fontSize * 1.2) -- 20% bigger
    local verseFont = love.graphics.newFont("font/EightBitDragon-anqx.ttf", verseFontSize)

    -- Draw verse reference centered at the top of parchment
    love.graphics.setFont(verseFont) -- Set verse font
    love.graphics.setColor(0.353, 0.196, 0.078, 1) -- Burnt brown text for visibility
    local padding = 70 * parchmentScale -- Padding for left and right, scaled
    local textX = parchmentX + padding -- Left padding
    local textY = parchmentY + 50 * parchmentScale -- 50px top padding, scaled
    local textWidth = scaledParchmentWidth - 2 * padding -- Width for text
    local lineHeight = fontSize * 1.5 -- Custom line height for Scripture text
    local verseLineHeight = verseFontSize * 1.5 -- Line height for verse reference
    local verseWidth = verseFont:getWidth(self.verse)
    local verseX = appWidth / 2 - verseWidth / 2 -- Center verse
    love.graphics.print(self.verse, verseX, textY)

    -- Draw message text below the verse on parchment
    love.graphics.setFont(dynamicFont) -- Set dynamic font for Scripture text
    local scriptureY = textY + verseLineHeight + 10 * parchmentScale -- Verse height plus 10px padding
    local lines = self:splitText(self.displayedText, dynamicFont, textWidth)
    for i, line in ipairs(lines) do
        local lineWidth = dynamicFont:getWidth(line)
        local lineX = appWidth / 2 - lineWidth / 2 -- Center each line
        love.graphics.print(line, lineX, scriptureY + (i - 1) * lineHeight)
    end

    love.graphics.setFont(love.graphics.getFont()) -- Reset to default font
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

function message:keypressed(key)
    if self.isActive and key ~= "a" and key ~= "s" and key ~= "r" and key ~= "c" then
        self:hide()
        return true -- Indicate key was handled
    end
    return false
end