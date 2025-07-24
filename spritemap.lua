local spriteMap = {
    Cody = {
        Standing = {
            Down = { frames = { { sprite = 1, duration = 0.2 }, { sprite = 1, duration = 0.2 }, { sprite = 2, duration = 0.2 }, { sprite = 3, duration = 0.2 }, { sprite = 2, duration = 0.2 } } },
            Up = { frames = { { sprite = 16, duration = 0.2 } } },
            Right = { frames = { { sprite = 31, duration = 0.2 } } },
            Left = { frames = { { sprite = 31, duration = 0.2 } } }
        },
        Walking = {
            Down = { frames = { { sprite = 5, duration = 0.2 }, { sprite = 6, duration = 0.2 }, { sprite = 7, duration = 0.2 }, { sprite = 8, duration = 0.2 }, { sprite = 9, duration = 0.2 }, { sprite = 10, duration = 0.2 } } },
            Up = { frames = { { sprite = 20, duration = 0.2 }, { sprite = 21, duration = 0.2 }, { sprite = 22, duration = 0.2 }, { sprite = 23, duration = 0.2 }, { sprite = 24, duration = 0.2 }, { sprite = 25, duration = 0.2 } } },
            Right = { frames = { { sprite = 35, duration = 0.2 }, { sprite = 36, duration = 0.2 }, { sprite = 37, duration = 0.2 }, { sprite = 38, duration = 0.2 }, { sprite = 39, duration = 0.2 }, { sprite = 40, duration = 0.2 } } },
            Left = { frames = { { sprite = 35, duration = 0.2 }, { sprite = 36, duration = 0.2 }, { sprite = 37, duration = 0.2 }, { sprite = 38, duration = 0.2 }, { sprite = 39, duration = 0.2 }, { sprite = 40, duration = 0.2 } } }
        },
        ["Jumping-Start"] = {
            Down = { frames = { { sprite = 13, duration = 0.2 } } },
            Up = { frames = { { sprite = 13, duration = 0.2 } } },
            Right = { frames = { { sprite = 13, duration = 0.2 } } },
            Left = { frames = { { sprite = 13, duration = 0.2 } } }
        },
        ["Jumping-Up"] = {
            Down = { frames = { { sprite = 11, duration = 0.2 } } },
            Up = { frames = { { sprite = 11, duration = 0.2 } } },
            Right = { frames = { { sprite = 26, duration = 0.2 } } },
            Left = { frames = { { sprite = 41, duration = 0.2 } } }
        },
        ["Jumping-Down"] = {
            Down = { frames = { { sprite = 12, duration = 0.2 } } },
            Up = { frames = { { sprite = 12, duration = 0.2 } } },
            Right = { frames = { { sprite = 42, duration = 0.2 } } },
            Left = { frames = { { sprite = 42, duration = 0.2 } } }
        },
        Plowing = {
            Down = { frames = { { sprite = 46, duration = 0.125 }, { sprite = 47, duration = 0.125 }, { sprite = 48, duration = 0.125 }, { sprite = 49, duration = 0.125 } } },
            Up = { frames = { { sprite = 61, duration = 0.125 }, { sprite = 62, duration = 0.125 }, { sprite = 63, duration = 0.125 }, { sprite = 64, duration = 0.125 } } },
            Right = { frames = { { sprite = 76, duration = 0.125 }, { sprite = 77, duration = 0.125 }, { sprite = 78, duration = 0.125 }, { sprite = 79, duration = 0.125 } } },
            Left = { frames = { { sprite = 76, duration = 0.125 }, { sprite = 77, duration = 0.125 }, { sprite = 78, duration = 0.125 }, { sprite = 79, duration = 0.125 } } }
        },
        Sowing = {
            Down = { frames = { { sprite = 50, duration = 0.125 }, { sprite = 51, duration = 0.125 }, { sprite = 52, duration = 0.125 } } },
            Up = { frames = { { sprite = 65, duration = 0.125 }, { sprite = 66, duration = 0.125 }, { sprite = 67, duration = 0.125 } } },
            Right = { frames = { { sprite = 80, duration = 0.125 }, { sprite = 81, duration = 0.125 }, { sprite = 82, duration = 0.125 } } },
            Left = { frames = { { sprite = 80, duration = 0.125 }, { sprite = 81, duration = 0.125 }, { sprite = 82, duration = 0.125 } } }
        },
        Watering = {
            Down = { frames = { { sprite = 91, duration = 0.125 }, { sprite = 92, duration = 0.125 }, { sprite = 93, duration = 0.125 }, { sprite = 94, duration = 0.125 } } },
            Up = { frames = { { sprite = 106, duration = 0.125 }, { sprite = 107, duration = 0.125 }, { sprite = 108, duration = 0.125 }, { sprite = 109, duration = 0.125 } } },
            Right = { frames = { { sprite = 121, duration = 0.125 }, { sprite = 122, duration = 0.125 }, { sprite = 123, duration = 0.125 }, { sprite = 124, duration = 0.125 } } },
            Left = { frames = { { sprite = 121, duration = 0.125 }, { sprite = 122, duration = 0.125 }, { sprite = 123, duration = 0.125 }, { sprite = 124, duration = 0.125 } } }
        },
        PickUp = {
            Down = { frames = { { sprite = 95, duration = 0.125 }, { sprite = 96, duration = 0.125 }, { sprite = 98, duration = 1 } } },
            Up = { frames = { { sprite = 110, duration = 0.125 }, { sprite = 111, duration = 0.125 }, { sprite = 112, duration = 1 } } },
            Right = { frames = { { sprite = 125, duration = 0.125 }, { sprite = 126, duration = 0.125 }, { sprite = 127, duration = 1 } } },
            Left = { frames = { { sprite = 125, duration = 0.125 }, { sprite = 126, duration = 0.125 }, { sprite = 127, duration = 1 } } }
        }
    }
}

return spriteMap