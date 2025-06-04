
local Umath = require("modules/Umath")
local Usprites = require("modules/Usprites")


local enemies = {} -- table to hold all enemies

enemies.E_GOBLIN = {
    name = "Goblin",
    health = 11, 
    attack = 3.2, 
    strengthGrowth = 0.01,
    defense = 0.5,
    speed = 0.6,
    reward = 8, -- reward for defeating this enemy
    spr = Usprites.spr_enemy_goblin,
    attackCooldown = Umath.Floor(30/0.6), -- frames to wait before attacking again
    ATTACKCOOLDOWN = Umath.Floor(30/0.6), -- frames to wait before attacking again
}

enemies.E_SLIME = {
    name = "Slime",
    health = 12, 
    attack = 3.3,
    strengthGrowth = 0.02,
    defense = 0,
    speed = 1,
    reward = 5, -- reward for defeating this enemy
    spr = Usprites.spr_enemy_slime,
    attackCooldown = 30, -- frames to wait before attacking again
    ATTACKCOOLDOWN = 30, -- frames to wait before attacking again
}

--= Enemy stats ==========--
enemies.ENEMY_STRENGTH_MP = 0.95 
-- Final STR = Base STR × Loop Count × (1 + Difficulty Enemy Strength) × (1 + (Loop Count - 1) × Difficulty Enemy Strength Growth)

function enemies.ScaleEnemy(_enemy)
    local l = obj_hero.vars.loop
    _enemy.health = Umath.Floor(_enemy.health + l * (1 + enemies.ENEMY_STRENGTH_MP) * (1+(l-1) * _enemy.strengthGrowth))
    _enemy.attack = Umath.Floor(_enemy.attack + l * (1 + enemies.ENEMY_STRENGTH_MP) * (1+(l-1) * _enemy.strengthGrowth))
end


return enemies -- return the enemies table
