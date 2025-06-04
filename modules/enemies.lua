
local umath = require("modules/umath")
local usprites = require("modules/usprites")


local enemies = {} -- table to hold all enemies

enemies.E_GOBLIN = {
    name = "Goblin",
    health = 11, 
    attack = 3.2, 
    strengthGrowth = 0.01,
    defense = 0.5,
    speed = 0.6,
    reward = 8, -- reward for defeating this enemy
    spr = usprites.spr_enemy_goblin,
    attackCooldown = umath.Floor(30/0.6), -- frames to wait before attacking again
    ATTACKCOOLDOWN = umath.Floor(30/0.6), -- frames to wait before attacking again
}

enemies.E_SLIME = {
    name = "Slime",
    health = 12, 
    attack = 3.3,
    strengthGrowth = 0.02,
    defense = 0,
    speed = 1,
    reward = 5, -- reward for defeating this enemy
    spr = usprites.spr_enemy_slime,
    attackCooldown = 30, -- frames to wait before attacking again
    ATTACKCOOLDOWN = 30, -- frames to wait before attacking again
}

return enemies -- return the enemies table
