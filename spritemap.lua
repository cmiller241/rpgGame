local spriteMap = {
    Cody = {
        Standing = {
            Down = {1,1,2,3,2},
            Up = {16},
            Right = {31},
            Left = {31}
        },
        Walking = {
            Down = {5,6,7,8,9,10},
            Up = {20,21,22,23,24,25},
            Right = {35,36,37,38,39,40},
            Left = {35,36,37,38,39,40}                
        },
        ["Jumping-Start"] = {
            Down={13},
            Up={13},
            Right={13},
            Left={13}
        },
        ["Jumping-Up"] = {
            Down = {11},
            Up = {11},
            Right = {26},
            Left = {41}
        },
        ["Jumping-Down"] = {
            Down = {12},
            Up = {12},
            Right = {42},
            Left = {42}
        },
        Plowing = {
            Down = {46,47,48,49},
            Up = {61,62,63,64},
            Right = {76,77,78,79},
            Left = {76,77,78,79}           
        },
        Sowing = {
            Down = {50,51,52},
            Up = {65,66,67},
            Right = {80,81,82},
            Left = {80,81,82}
        },
        Watering = {
            Down = {91,92,93,94},
            Up = {106,107,108,109},
            Right = {121,122,123,124},
            Left = {121,122,123,124}
        }
    }
}

return spriteMap