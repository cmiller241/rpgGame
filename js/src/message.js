// message.js
//
// The message box shown after picking up a Bible page: the verse on a
// parchment, then the new tool and its description in a text box.

import love from '../love/index.js';
import player from './player.js';
import sprites from './sprites.js';
import toolbarMap from './toolbarMap.js';

const message = {};
export default message;

// Fonts are cached by size: creating a font is slow and the old code made
// three new ones every frame while a message was showing.
const FONT_PATH = 'font/EightBitDragon-anqx.ttf';
const fontCache = new Map();
function getFont(size) {
  if (!fontCache.has(size)) {
    fontCache.set(size, love.graphics.newFont(FONT_PATH, size));
  }
  return fontCache.get(size);
}
message.isActive = false; // Whether a message box is displayed
message.text = ''; // Stored message from picked-up object
message.verse = ''; // Stored verse reference (book and verse)
message.displayedText = ''; // Currently displayed text (built character by character)
message.charIndex = 0; // Current character index for typing
message.typingTimer = 0; // Timer for typing speed
message.typingSpeed = 0.00; // Time per character in seconds (adjust for speed)
message.displayTimer = 0; // Timer for displaying the parchment
message.tool = null; // Stored tool quad index from picked-up object
message.toolMessage = ''; // Stored tool message from picked-up object
message.displayedToolText = ''; // Currently displayed tool message
message.toolCharIndex = 0; // Current character index for tool message typing
message.toolTypingTimer = 0; // Timer for tool message typing
message.toolTypingSpeed = 0.02; // Time per character for tool message

message.show = function () {
  this.isActive = true;
  this.displayedText = ''; // Reset displayed text
  this.charIndex = 0; // Reset character index
  this.typingTimer = 0; // Reset timer
  this.displayTimer = 0; // Reset display timer
  this.displayedToolText = ''; // Reset displayed tool text
  this.toolCharIndex = 0; // Reset tool character index
  this.toolTypingTimer = 0; // Reset tool typing timer
};

message.hide = function () {
  if (this.tool) {
    // Put the new tool in the first empty toolbar position.
    for (let i = 0; i < 10; i++) {
      if (toolbarMap.visibleSlots[i] === 1) {
        toolbarMap.visibleSlots[i] = this.tool;
        break;
      }
    }
  }
  this.isActive = false;
  this.text = ''; // Clear message
  this.verse = ''; // Clear verse
  this.tool = null; // Clear tool
  this.toolMessage = ''; // Clear tool message
  // Reset player state to Standing
  player.state = 'Standing';
  player.frame = 1;
  player.frameTime = 0;
};

message.update = function (dt) {
  if (!this.isActive) return;
  this.displayTimer = this.displayTimer + dt; // Increment display timer

  // Update parchment text typing
  if (this.typingSpeed === 0) {
    this.charIndex = this.text.length;
    this.displayedText = this.text;
  } else if (this.charIndex < this.text.length) {
    this.typingTimer = this.typingTimer + dt;
    if (this.typingTimer >= this.typingSpeed) {
      this.charIndex = this.charIndex + 1;
      this.displayedText = this.text.slice(0, this.charIndex);
      this.typingTimer = 0;
    }
  }

  // Update tool message typing (only when textbox is visible)
  if (this.displayTimer >= 1) {
    if (this.toolTypingSpeed === 0) {
      this.toolCharIndex = this.toolMessage.length;
      this.displayedToolText = this.toolMessage;
    } else if (this.toolCharIndex < this.toolMessage.length) {
      this.toolTypingTimer = this.toolTypingTimer + dt;
      if (this.toolTypingTimer >= this.toolTypingSpeed) {
        this.toolCharIndex = this.toolCharIndex + 1;
        this.displayedToolText = this.toolMessage.slice(0, this.toolCharIndex);
        this.toolTypingTimer = 0;
      }
    }
  }
};

// Helper function to split text into lines
message.splitText = function (text, font, maxWidth) {
  const lines = [];
  let currentLine = '';
  const spaceWidth = font.getWidth(' ');
  const words = text.match(/\S+/g) || [];
  let wordIndex = 0;
  let lineWidth = 0;

  while (wordIndex < words.length) {
    const word = words[wordIndex];
    const wordWidth = font.getWidth(word);

    if (lineWidth + wordWidth <= maxWidth) {
      currentLine = currentLine + (currentLine === '' ? word : ' ' + word);
      lineWidth = lineWidth + wordWidth + (currentLine === word ? 0 : spaceWidth);
      wordIndex = wordIndex + 1;
    } else {
      if (currentLine !== '') {
        lines.push(currentLine);
        currentLine = '';
        lineWidth = 0;
      } else {
        // Word is too long for one line; split it
        let partialWord = '';
        let partialWidth = 0;
        for (const char of word) {
          const charWidth = font.getWidth(char);
          if (partialWidth + charWidth <= maxWidth) {
            partialWord = partialWord + char;
            partialWidth = partialWidth + charWidth;
          } else {
            lines.push(partialWord);
            partialWord = char;
            partialWidth = charWidth;
          }
        }
        if (partialWord !== '') {
          currentLine = partialWord;
          lineWidth = partialWidth;
        }
        wordIndex = wordIndex + 1;
      }
    }
  }
  if (currentLine !== '') {
    lines.push(currentLine);
  }
  return lines;
};

message.draw = function (appWidth, appHeight) {
  if (!this.isActive) return;
  love.graphics.setColor(1, 1, 1, 1);

  // Draw parchment centered at screen's horizontal center, 20 pixels from top
  const parchmentWidth = sprites.parchment.getWidth();
  const maxWidth = 0.8 * appWidth;
  const parchmentScale = Math.min(1.0, maxWidth / parchmentWidth);
  const scaledParchmentWidth = parchmentWidth * parchmentScale;
  const parchmentX = appWidth / 2 - scaledParchmentWidth / 2;
  const parchmentY = 20;
  love.graphics.draw(sprites.parchment, parchmentX, parchmentY, 0, parchmentScale, parchmentScale);

  // Draw textbox at bottom center after 1 second, at least 80% of screen width
  if (this.displayTimer >= 1) {
    const textboxWidth = sprites.textbox.getWidth();
    const textboxHeight = sprites.textbox.getHeight();
    const textboxScale = Math.max(maxWidth / textboxWidth, 0.8 * appWidth / textboxWidth);
    const scaledTextboxWidth = textboxWidth * textboxScale;
    const scaledTextboxHeight = textboxHeight * textboxScale;
    const textboxX = appWidth / 2 - scaledTextboxWidth / 2;
    const textboxY = appHeight - 20 - scaledTextboxHeight;
    love.graphics.draw(sprites.textbox, textboxX, textboxY, 0, textboxScale, textboxScale);

    // Draw the toolbar sprite quad and tool message if set
    if (this.tool) {
      const padding = 30 * textboxScale; // Increased padding for icon and text
      const iconBaseSize = 60; // Assuming base size of toolbar quads is 60x60
      const iconScale = (scaledTextboxHeight - 2 * padding) / iconBaseSize;
      const iconSize = iconBaseSize * iconScale;
      const iconX = textboxX + padding;
      const iconY = textboxY + (scaledTextboxHeight - iconSize) / 2;
      love.graphics.draw(sprites.toolbar, sprites.toolbarQuads[this.tool], iconX, iconY, 0, iconScale, iconScale);

      // Draw tool message to the right of the icon
      if (this.toolMessage) {
        const dynamicFont = getFont(Math.floor(Math.max(20 * appWidth / 1280, 16)));
        love.graphics.setFont(dynamicFont);
        love.graphics.setColor(1, 1, 1, 1); // White text for toolMessage
        const textX = iconX + iconSize + 20 * textboxScale; // Increased margin to 20px from icon
        const textY = textboxY + padding; // 20px padding from top
        const textWidth = scaledTextboxWidth - (textX - textboxX) - padding; // Remaining width minus right padding
        const lineHeight = dynamicFont.getHeight() * 1.5;
        const lines = this.splitText(this.displayedToolText, dynamicFont, textWidth);
        lines.forEach((line, i) => {
          love.graphics.print(line, textX, textY + i * lineHeight);
        });
      }
    }
  }

  // Dynamic font size based on appWidth
  const baseFontSize = 20;
  const fontSizeFactor = appWidth / 1280; // Relative to base width of 1280 pixels
  const fontSize = Math.floor(Math.max(baseFontSize * fontSizeFactor, 16)); // Clamp at minimum 16
  const dynamicFont = getFont(fontSize);

  // Verse font (slightly bigger)
  const verseFontSize = Math.floor(fontSize * 1.2); // 20% bigger
  const verseFont = getFont(verseFontSize);

  // Draw verse reference centered at the top of parchment
  love.graphics.setFont(verseFont); // Set verse font
  love.graphics.setColor(0.353, 0.196, 0.078, 1); // Burnt brown text for visibility
  const padding = 70 * parchmentScale; // Padding for left and right, scaled
  const textY = parchmentY + 50 * parchmentScale; // 50px top padding, scaled
  const textWidth = scaledParchmentWidth - 2 * padding; // Width for text
  const lineHeight = fontSize * 1.5; // Custom line height for Scripture text
  const verseLineHeight = verseFontSize * 1.5; // Line height for verse reference
  const verseWidth = verseFont.getWidth(this.verse);
  const verseX = appWidth / 2 - verseWidth / 2; // Center verse
  love.graphics.print(this.verse, verseX, textY);

  // Draw message text below the verse on parchment
  love.graphics.setFont(dynamicFont); // Set dynamic font for Scripture text
  const scriptureY = textY + verseLineHeight + 10 * parchmentScale; // Verse height plus 10px padding
  const lines = this.splitText(this.displayedText, dynamicFont, textWidth);
  lines.forEach((line, i) => {
    const lineWidth = dynamicFont.getWidth(line);
    const lineX = appWidth / 2 - lineWidth / 2; // Center each line
    love.graphics.print(line, lineX, scriptureY + i * lineHeight);
  });

  love.graphics.setColor(1, 1, 1, 1); // Reset color
};

message.keypressed = function (key) {
  if (this.isActive && key !== 'a' && key !== 's' && key !== 'r' && key !== 'c') {
    this.hide();
    return true; // Indicate key was handled
  }
  return false;
};
