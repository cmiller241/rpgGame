// toolbarMap.js
//
// `slots` is keyed by quad number (1-14, the toolbar.png quads, as in the
// Lua), not a 0-based array: visibleSlots, the pages' `tool` and the
// message box all refer to tools by that number.

const toolbarMap = {
  slots: {
    1: { quad: 1, name: 'Empty' },
    2: { quad: 2, name: 'Paper' },
    3: { quad: 3, name: 'Boot' },
    4: { quad: 4, name: 'Hoe' },
    5: { quad: 5, name: 'Axe' },
    6: { quad: 6, name: 'Sickle' },
    7: { quad: 7, name: 'Sword' },
    8: { quad: 8, name: 'Hammer' },
    9: { quad: 9, name: 'Watering Can' },
    10: { quad: 10, name: 'Grass Seed' },
    11: { quad: 11, name: 'Tomato Seed' },
    12: { quad: 12, name: 'Corn Seed' },
    13: { quad: 13, name: 'Potato Seed' },
    14: { quad: 14, name: 'Carrot Seed' },
  },
  // The 10 toolbar positions (0-based), each holding a slot number above.
  visibleSlots: [4, 9, 10, 1, 1, 1, 1, 1, 1, 1], // All empty slots initially
};

export default toolbarMap;
