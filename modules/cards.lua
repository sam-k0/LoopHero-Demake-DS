local Usprites = require("modules/usprites")
local Enemies = require("modules/enemies")
local Umath = require("modules/umath")
local Copy = require("modules/copy")

local cards = {}

cards.CARD_ENUM = {
    EMPTY = "empty",
    MOUNTAIN = "mountain",
    ROAD = "road",
    ROAD_CAMP = "road_camp",
    ROAD_ENEMIES = "road_enemies",
    MEADOW = "meadow",
}


cards.CARD_TABLE_MOUNTAIN = {
    name = "Mountain",
    occupied = true,
    spr = Usprites.spr_card_mountain,
    type = cards.CARD_ENUM.MOUNTAIN,
    initFunc = function(tile)
        obj_hero.vars.MAXHEALTH = obj_hero.vars.MAXHEALTH + 10
    end,
    removeFunc = function(tile) end,
    enterFunc = nil,
    updateFunc = nil,
    data = {},
}

cards.CARD_TABLE_ROAD_CAMP = {
    name = "Road Camp",
    spr = nil,
    occupied = true,
    type = cards.CARD_ENUM.ROAD_CAMP,
    initFunc = nil,
    removeFunc = nil,
    enterFunc = function(tile)
        obj_hero.vars.health = obj_hero.vars.health + obj_hero.vars.MAXHEALTH * 0.1
        if obj_hero.vars.health > obj_hero.vars.MAXHEALTH then
            obj_hero.vars.health = obj_hero.vars.MAXHEALTH
        end
        obj_hero.vars.loop = obj_hero.vars.loop + 1
        screen.print(SCREEN_UP, 64, 64, "You found a camp! Resting...")
    end,
    updateFunc = nil,
    data = {},
}

cards.CARD_TABLE_ROAD = {
    name = "Road",
    spr = nil,
    type = cards.CARD_ENUM.ROAD,
    initFunc = nil,
    removeFunc = nil,
    enterFunc = function(tile)
        if #tile.data.enemies > 0 then
            GAMESTATE.HEROSTATE = HS_FIGHTING
            obj_hero.vars.attackCooldown = obj_hero.vars.ATTACKCOOLDOWN
        end
    end,
    updateFunc = function(tile)
        tile.data.spawnTimer = tile.data.spawnTimer - 1
        if tile.data.spawnTimer <= 0 then
            tile.data.spawnTimer = Umath.RandomRange(tile.data.minSpawnTimer, tile.data.maxSpawnTimer)
            if Umath.Random() < 0.1 then
                if #tile.data.enemies == tile.data.maxEnemies then
                    return false
                end
                local enemy = Copy.CopyShallow(Umath.RandomChoice({Enemies.E_GOBLIN, Enemies.E_SLIME}))
                Enemies.ScaleEnemy(enemy)
                table.insert(tile.data.enemies, enemy)
                return true
            end
        end
        return false
    end,
    data = {
        enemies = {},
        spawnTimer = 0,
        minSpawnTimer = 120,
        maxSpawnTimer = 300,
        maxEnemies = 3,
    }
}

cards.CARD_TABLE_MEADOW = {
    name = "Meadow",
    spr = Usprites.spr_card_meadow,
    type = cards.CARD_ENUM.MEADOW,
    occupied = true,
    initFunc = function(tile)
        obj_hero.vars.regeneration = obj_hero.vars.regeneration + 0.5
    end,
    removeFunc = nil,
    enterFunc = nil,
    updateFunc = nil,
    data = {},
}

cards.CARD_TABLE_EMPTY = {
    name = "Empty",
    spr = nil,
    type = cards.CARD_ENUM.EMPTY,
    occupied = false,
    initFunc = nil,
    removeFunc = nil,
    enterFunc = nil,
    updateFunc = nil,
    data = {},
}

cards.enemyDropTable = 
{
    [Enemies.E_GOBLIN.name] = {
        chance = 0.5,
        cards = {cards.CARD_TABLE_MOUNTAIN, cards.CARD_TABLE_MEADOW},
    },
    [Enemies.E_SLIME.name] = {
        chance = 0.3,
        cards = {cards.CARD_TABLE_MEADOW},
    },
}

function cards.cardTableToTileTable(cardTable)
    if not cardTable.data then
        cardTable.data = {}
    end

    return {
        name = cardTable.name,
        occupied = cardTable.occupied,
        spr = obj_tilegrid.vars.tileSprites[cardTable.type],
        type = cardTable.type,
        initFunc = cardTable.initFunc,
        removeFunc = cardTable.removeFunc,
        enterFunc = cardTable.enterFunc,
        updateFunc = cardTable.updateFunc,
        data = Copy.CopyDeep(cardTable.data) or {},
    }
end

return cards

