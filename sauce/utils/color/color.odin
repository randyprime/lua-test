package color

Vec4 :: [4]f32

WHITE :: Vec4 {1,1,1,1}
BLACK :: Vec4 {0,0,0,1}
RED :: Vec4 {1,0,0,1}
GREEN :: Vec4 {0,1,0,1}
BLUE :: Vec4 {0,0,1,1}
GRAY :: Vec4{0.5,0.5,0.5,1.0}
CYAN :: PRETTY_BLUE
YELLOW :: Vec4{1, 1, 0, 1}

MAGENTA :: Vec4{0.8, 0.3, 0.6, 1.0}

PRETTY_BLUE :: Vec4{ 115.0 / 255.0, 190.0 / 255.0, 211.0 / 255.0, 1.0}
PRETTY_GREEN :: Vec4 {117.0 / 255.0, 167.0 / 255.0, 67.0 / 255.0, 1.0}
PRETTY_RED :: Vec4 {205.0 / 255.0, 48.0 / 255.0, 48.0 / 255.0, 1.0}
PRETTY_ORANGE :: Vec4 {218.0 / 255.0, 134.0 / 255.0, 62.0 / 255.0, 1.0}
PRETTY_LIGHT_BLUE :: Vec4 {164.0 / 255.0, 221.0 / 255.0, 219.0 / 255.0, 1.0}

DARK_GRAY :: Vec4 { 57.0 / 255.0, 74.0 / 255.0, 80.0 / 255.0, 1.0 }

GOLD :: Vec4 { 232.0 / 255.0, 193.0 / 255.0, 112.0 / 255.0, 1.0 }
DARK_GOLD :: Vec4 { 190.0 / 255.0, 119.0 / 255.0, 43.0 / 255.0, 1.0 }

// this is from minecraft, it's a perfectly balanced gray for item slots
MC_GRAY :: Vec4 { 139.0 / 255.0, 139.0 / 255.0, 139.0 / 255.0, 1.0 }