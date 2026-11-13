// ui.js
//
// The toolbar (inventory) along the bottom of the screen.
// Positions are 0-based here: highlightedSlot runs 0..9.

import love from '../love/index.js';
import sprites from './sprites.js';
import toolbarMap from './toolbarMap.js';

const ui = {};
export default ui;

const NUM_SLOTS = 10;

ui.highlightedSlot = 0; // Track the currently highlighted slot (0 to 9)
ui.slotScales = []; // Current scale for each slot
ui.slotTargetScales = []; // Target scale for each slot
ui.slotScaleTimers = []; // Animation timers for each slot (0 to 1)
ui.animationDuration = 0.2; // Animation duration for scaling
ui.isVisible = true; // Track if inventory is visible
ui.centerY = 0; // Current vertical center position
ui.targetCenterY = 0; // Target vertical center position
ui.centerYTimer = 1; // Animation timer for centerY (0 to 1)
ui.slideDuration = 1; // Animation duration for sliding
ui.baseSlotSize = 60; // Base size of inventory slot sprite
ui.defaultScale = 2; // Default scale factor
ui.highlightScaleFactor = 1.1; // Highlighted slot scale multiplier
ui.appHeight = 0; // Store appHeight
ui.highlightScale = 0; // Store highlightScale

// Initialize slot scales and timers
for (let i = 0; i < NUM_SLOTS; i++) {
  ui.slotScales[i] = ui.defaultScale; // Default scale
  ui.slotTargetScales[i] = ui.defaultScale; // Default target scale
  ui.slotScaleTimers[i] = 1; // No animation initially
}
ui.slotTargetScales[0] = ui.defaultScale * ui.highlightScaleFactor; // Highlighted slot starts scaled up

ui.drawInventory = function (appWidth, appHeight) {
  if (!this.isVisible && this.centerYTimer >= 1) {
    return; // Skip drawing if fully hidden
  }

  // Update appHeight to ensure latest dimensions
  this.appHeight = appHeight;

  const baseSlotSize = this.baseSlotSize;
  const defaultScale = this.defaultScale;
  const numSlots = NUM_SLOTS; // Number of inventory slots
  const minMargin = 3; // Minimum margin between slots
  const usableWidth = 0.6 * appWidth; // Inventory takes up 60% of screen width

  // Calculate margin with default scale
  const highlightScaleFactor = this.highlightScaleFactor;
  let scale = defaultScale;
  let highlightScale = scale * highlightScaleFactor;
  let slotSize = baseSlotSize * scale;
  let highlightSlotSize = baseSlotSize * highlightScale;
  let totalSlotWidth = (numSlots - 1) * slotSize + highlightSlotSize;
  let margin = (usableWidth - totalSlotWidth) / (numSlots - 1);

  // Adjust scale if margin is too small
  if (margin < minMargin) {
    scale = (usableWidth - (numSlots - 1) * minMargin) / (numSlots * baseSlotSize);
    highlightScale = scale * highlightScaleFactor;
    slotSize = baseSlotSize * scale;
    highlightSlotSize = baseSlotSize * highlightScale;
    totalSlotWidth = (numSlots - 1) * slotSize + highlightSlotSize;
    margin = minMargin;
  }

  // Store highlightScale
  this.highlightScale = highlightScale;

  // Update target scales for animation
  for (let i = 0; i < numSlots; i++) {
    this.slotTargetScales[i] = i === this.highlightedSlot ? highlightScale : scale;
  }

  // Initialize or update centerY if not set or outdated
  if (this.centerY === 0 || Math.abs(this.centerY - (appHeight - baseSlotSize * highlightScale / 2 - 10)) > 0.001) {
    this.centerY = appHeight - baseSlotSize * highlightScale / 2 - 10;
    this.targetCenterY = this.centerY;
  }

  // Starting x to center the inventory
  const totalWidthWithMargins = totalSlotWidth + (numSlots - 1) * margin;
  const startX = (appWidth - totalWidthWithMargins) / 2;

  let currentX = startX;
  for (let i = 0; i < numSlots; i++) {
    const currentScale = this.slotScales[i];
    const size = baseSlotSize * currentScale;
    const ox = baseSlotSize / 2;
    const oy = baseSlotSize / 2;
    const drawX = currentX + size / 2;
    const drawY = this.centerY;
    const alpha = i === this.highlightedSlot ? 1.0 : 0.5;
    love.graphics.setColor(1, 1, 1, alpha);
    // Use the quad from visibleSlots
    const quadIndex = toolbarMap.visibleSlots[i];
    love.graphics.draw(sprites.toolbar, sprites.toolbarQuads[quadIndex], drawX, drawY, 0, currentScale, currentScale, ox, oy);
    currentX = currentX + size + margin;
  }

  love.graphics.setColor(1, 1, 1, 1);
};

ui.resize = function (appWidth, appHeight) {
  // Update appHeight and reposition toolbar
  this.appHeight = appHeight;
  // Recalculate target centerY based on new appHeight
  this.targetCenterY = appHeight - this.baseSlotSize * this.highlightScale / 2 - 10;
  this.centerYTimer = 0; // Trigger animation to new position
};

ui.update = function (dt) {
  // Update scaling animations
  for (let i = 0; i < NUM_SLOTS; i++) {
    const current = this.slotScales[i];
    const target = this.slotTargetScales[i];
    const diff = Math.abs(current - target);

    if (diff > 0.001) {
      this.slotScaleTimers[i] = Math.min(this.slotScaleTimers[i] + dt / this.animationDuration, 1);
      const t = this.slotScaleTimers[i];
      const easedT = t * t * (3 - 2 * t); // Smooth in-out easing
      this.slotScales[i] = current + (target - current) * easedT;
    } else {
      this.slotScales[i] = target;
      this.slotScaleTimers[i] = 1;
    }
  }

  // Update centerY animation
  if (Math.abs(this.centerY - this.targetCenterY) > 0.001) {
    this.centerYTimer = Math.min(this.centerYTimer + dt / this.slideDuration, 1);
    const t = this.centerYTimer;
    const easedT = t * t * (3 - 2 * t); // Smooth in-out easing
    this.centerY = this.centerY + (this.targetCenterY - this.centerY) * easedT;
  } else {
    this.centerY = this.targetCenterY;
    this.centerYTimer = 1;
  }
};

ui.keypressed = function (key) {
  const prevSlot = this.highlightedSlot;
  if (key === 'a') {
    this.highlightedSlot = Math.max(0, this.highlightedSlot - 1);
  } else if (key === 's') {
    this.highlightedSlot = Math.min(NUM_SLOTS - 1, this.highlightedSlot + 1);
  } else if (key === 'r') {
    this.isVisible = !this.isVisible;
    if (this.isVisible) {
      // Show: animate back to original position
      this.targetCenterY = this.appHeight - this.baseSlotSize * this.highlightScale / 2 - 10;
    } else {
      // Hide: animate up 20 pixels, then down off-screen
      this.centerY = this.centerY - 20;
      this.targetCenterY = this.appHeight + this.baseSlotSize * this.highlightScale / 2;
    }
    this.centerYTimer = 0;
  }

  if (prevSlot !== this.highlightedSlot) {
    this.slotScaleTimers[prevSlot] = 0;
    this.slotScaleTimers[this.highlightedSlot] = 0;
  }
};
