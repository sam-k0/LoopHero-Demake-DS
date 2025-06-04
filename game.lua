---@diagnostic disable: undefined-global
-- Loop Hero reimplementation for Nintendo DS Lua (microLua DS)
-- Original game by Four Quarters 
-- This is a reimplementation of the game mechanics and features and does not use any code from the original game.
-- Assets are taken from the original game, some are modified to fit the limits of the Nintendo DS.

-- This (the code) is open source, freely editable and free to use without warranty.
-- Code written by sam-k0

local Image = require("Image")
local Gamegui = require("modules/gui")
local Umath = require("modules/umath")
local Usprites = require("modules/usprites") -- load sprites module
local Enemies = require("modules/enemies") -- load enemies module
local Copy = require("modules/copy") -- load copy module
local Cards = require("modules/cards") -- load cards module

--= Global Variables ==========--
objList = {} -- list of objects

obj_hero = nil -- hero object
obj_tilegrid = nil -- tile grid object
--= GAME states ==========--
GS_PLAYING = 0
GS_PAUSED = 1
GS_GAMEOVER = 2

HS_WALKING = 0
HS_FIGHTING = 1

GAMESTATE = {
    PAUSED = GS_PLAYING,
    HEROSTATE = HS_WALKING
}



--= Grid and path functions ==========--


-- Check if position is within grid bounds
function inBounds(x, y, w, h)
    return x >= 1 and x <= w and y >= 1 and y <= h
end

-- Generate a non-overlapping, closed loop path
function randomPath()
    local w = obj_tilegrid.vars.gridWidth
    local h = obj_tilegrid.vars.gridHeight
    local path = {}
    local visited = {}

    -- Helper to mark a tile as visited
    local function mark(x, y)
        visited[y] = visited[y] or {}
        visited[y][x] = true
    end

    -- Helper to check if a tile is visited
    local function isVisited(x, y)
        return visited[y] and visited[y][x]
    end

    -- Helper to check if a tile is on the edge
    local function isEdge(x, y)
        return x == 1 or x == w or y == 1 or y == h
    end

    -- Get all edge tiles
    local edgeTiles = {}
    for j = 1, h do
        for i = 1, w do
            if isEdge(i, j) then
                table.insert(edgeTiles, {x = i, y = j})
            end
        end
    end

    -- Pick a random starting edge tile
    local start = edgeTiles[1]--Umath.RandomChoice(edgeTiles)
    local x, y = start.x, start.y
    table.insert(path, {x = x, y = y})
    mark(x, y)

    -- Directions: right, down, left, up
    local dirs = {
        {dx = 1, dy = 0},
        {dx = 0, dy = 1},
        {dx = -1, dy = 0},
        {dx = 0, dy = -1}
    }

    -- Shuffle helper using Umath.RandomRange
    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = Umath.RandomRange(1, i)
            t[i], t[j] = t[j], t[i]
        end
    end

    local steps = 1
    local maxSteps = 2 * (w + h) -- perimeter, enough to loop

    while true do
        local candidates = {}
        for _, dir in ipairs(dirs) do
            local nx, ny = x + dir.dx, y + dir.dy
            if isEdge(nx, ny) and not isVisited(nx, ny) and inBounds(nx, ny, w, h) then
                table.insert(candidates, {x = nx, y = ny})
            end
        end

        -- If we can close the loop, do it
        if steps >= 4 then
            for _, dir in ipairs(dirs) do
                local nx, ny = x + dir.dx, y + dir.dy
                if nx == start.x and ny == start.y and steps >= maxSteps / 2 then
                    --table.insert(path, {x = nx, y = ny})
                    return path
                end
            end
        end

        if #candidates == 0 then
            -- No way to continue, restart
            return randomPath()
        end

        shuffle(candidates)
        local nextTile = candidates[1]
        x, y = nextTile.x, nextTile.y
        table.insert(path, {x = x, y = y})
        mark(x, y)
        steps = steps + 1
    end
end

function getAdjacentTiles(x,y,_type)
    -- Get adjacent tiles of a specific type
    local adjacent = {}
    local directions = {
        {dx = 1, dy = 0},  -- right
        {dx = -1, dy = 0}, -- left
        {dx = 0, dy = 1},  -- down
        {dx = 0, dy = -1}  -- up
    }
    for _, dir in ipairs(directions) do
        local nx, ny = x + dir.dx, y + dir.dy
        if inBounds(nx, ny, obj_tilegrid.vars.gridWidth, obj_tilegrid.vars.gridHeight) then
            local tile = obj_tilegrid.vars.tileGrid[ny][nx]
            if tile.type == _type or _type == nil then
                table.insert(adjacent, tile)
            end
        end
    end
    return adjacent
end





--= Create objects ==========--

function createObject(sprAnim,varTable,initFunc, updateFunc, drawFunc ) -- object is basically a sprite with an update function to take care of vars
    return {
        sprite = sprAnim,
        vars = varTable,
        init = initFunc,
        update = updateFunc,
        draw = drawFunc
    }
end

-- create tilegrid manager
obj_tilegrid = createObject(
    nil, -- no sprite
    {
        x=0,
        y=0,
        tileSize=16,
        gridWidth=14,
        gridHeight=8,
        tileGrid = {},
        tileSprites ={
            [Cards.CARD_ENUM.EMPTY] = Usprites.spr_tile_empty,
            [Cards.CARD_ENUM.ROAD] = Usprites.spr_tile_road,
            [Cards.CARD_ENUM.ROAD_ENEMIES] = Usprites.spr_tile_road_enemies,
            [Cards.CARD_ENUM.MOUNTAIN] = Usprites.spr_tile_mountain,
            [Cards.CARD_ENUM.ROAD_CAMP] = Usprites.spr_tile_road_camp,
            [Cards.CARD_ENUM.MEADOW] = Usprites.spr_tile_meadow,
        },
        tileCanvas = Canvas.new(), -- drawing onto canvas for performance
        canvasUpdate = true, -- flag to update canvas when needed
        roadPath = {}, -- this will hold the road path tiles in a sequence
        selectedCard = nil, -- currently selected card for placement
        heldCards = {
            Copy.CopyDeep(Cards.CARD_TABLE_MOUNTAIN), -- initial cards held by the player, can be expanded with more cards
            Copy.CopyDeep(Cards.CARD_TABLE_MOUNTAIN), -- duplicate for testing, can be removed later
            Copy.CopyDeep(Cards.CARD_TABLE_MEADOW), -- initial cards held by the player, can be expanded with more cards
        }, -- cards held by the player, for placing on the grid
        maxCards = 16, -- maximum number of cards that can be held
        cardPlaceToGridcoords = function(sx, sy)
            -- calculate grid's left edge as in the draw function
            local grid_left = 256 / 2 - obj_tilegrid.vars.tileSize * obj_tilegrid.vars.gridWidth / 2
            local x = Umath.Floor((sx - grid_left) / obj_tilegrid.vars.tileSize) + 1
            local y = Umath.Floor((sy - obj_tilegrid.vars.y) / obj_tilegrid.vars.tileSize) + 1
            return x, y
        end
    },
    function() -- init grid to empty
         
        -- grid
        for j = 1, obj_tilegrid.vars.gridHeight do
            obj_tilegrid.vars.tileGrid[j] = {}
            for i = 1, obj_tilegrid.vars.gridWidth do
                obj_tilegrid.vars.tileGrid[j][i] = Cards.cardTableToTileTable(Cards.CARD_TABLE_EMPTY) -- initialize each tile with empty tile data 
            end
        end
        -- make a connected looping road path
        local generatedPath = randomPath()
        for idx, pos in ipairs(generatedPath) do
            local x = pos.x
            local y = pos.y
            if inBounds(x, y, obj_tilegrid.vars.gridWidth, obj_tilegrid.vars.gridHeight) then -- assign road tile changes
                table.insert(obj_tilegrid.vars.roadPath, {x = x, y = y})
               
                obj_tilegrid.vars.tileGrid[y][x] = Cards.cardTableToTileTable(Cards.CARD_TABLE_ROAD)
                -- assign random spawn timer for the road tile
                obj_tilegrid.vars.tileGrid[y][x].data.spawnTimer = Umath.RandomRange(obj_tilegrid.vars.tileGrid[y][x].data.minSpawnTimer, obj_tilegrid.vars.tileGrid[y][x].data.maxSpawnTimer) -- set initial spawn timer
                
                if idx == 1 then-- check if we are processing the first tile in the path
                    obj_tilegrid.vars.tileGrid[y][x] = Cards.cardTableToTileTable(Cards.CARD_TABLE_ROAD_CAMP)
                end
            end
        end

    end, -- end init function
    function() -- update function

        -- If stylus is pressed, convert screen coordinates to grid coordinates
        if Stylus.newPress then
            if obj_tilegrid.vars.selectedCard then -- if a card is selected
                local x, y = obj_tilegrid.vars.cardPlaceToGridcoords(Stylus.X, Stylus.Y) -- convert screen coordinates to grid coordinates
                if inBounds(x, y, obj_tilegrid.vars.gridWidth, obj_tilegrid.vars.gridHeight) then -- check bounds
                    local tile = obj_tilegrid.vars.tileGrid[y][x]
                    if tile.occupied == false then -- if tile is not occupied
                        local cardIndex = obj_tilegrid.vars.selectedCard.cardSlotIndex -- get the index of the selected card
                        local cardData = obj_tilegrid.vars.selectedCard.cardData -- get the card data
                        local newtile = Cards.cardTableToTileTable(cardData)
                        if newtile.initFunc then
                            newtile.initFunc() 
                        end
                        newtile.occupied = true -- mark as occupied

                        obj_tilegrid.vars.heldCards[cardIndex] = nil -- remove the card from the held cards
                        obj_tilegrid.vars.tileGrid[y][x] = newtile -- place the new tile in the grid
                        obj_tilegrid.vars.canvasUpdate = true -- mark canvas for update
                        obj_tilegrid.vars.selectedCard = nil -- deselect card after placing it
                        GAMESTATE.PAUSED = GS_PLAYING
                    end
                else 
                    -- out of bounds, deselect card
                    obj_tilegrid.vars.selectedCard = nil
                    GAMESTATE.PAUSED = GS_PLAYING
                end
            else
                -- check if a card is tapped by checking if the stylus is within the card slots
                for i = 1, obj_tilegrid.vars.maxCards do
                    local x = 256 / 2 - Usprites.CARD_WIDTH * obj_tilegrid.vars.maxCards / 2 + (i - 1) * Usprites.CARD_WIDTH
                    local y = SCREEN_HEIGHT - Usprites.CARD_HEIGHT - 8 -- place cards at the bottom of the screen
                    if Stylus.X >= x and Stylus.X < x + Usprites.CARD_WIDTH and Stylus.Y >= y and Stylus.Y < y + Usprites.CARD_HEIGHT then
                        -- select the card if it exists
                        if i <= #obj_tilegrid.vars.heldCards then
                            -- selectedcard is a struct of {cardSlotIndex, cardData}
                            obj_tilegrid.vars.selectedCard = {
                                cardSlotIndex = i, -- index of the card slot
                                cardData = obj_tilegrid.vars.heldCards[i], -- data of the card
                            }                        
                            GAMESTATE.PAUSED = GS_PAUSED -- pause the game to allow card placement
                        end
                        break -- exit loop after selecting a card
                    end
                end
            end
        end
 ---- === Everything below this line is updated every frame if not in fight or paused!!! === ----
        if GAMESTATE.PAUSED == GS_PAUSED or GAMESTATE.HEROSTATE == HS_FIGHTING then
            return -- do not update grid 
        end

        -- update the tile grid
        for j = 1, obj_tilegrid.vars.gridHeight do
            for i = 1, obj_tilegrid.vars.gridWidth do
                local tile = obj_tilegrid.vars.tileGrid[j][i]
                
                if tile.updateFunc then -- if there is an update function assigned
                    if tile.updateFunc(tile) == true then
                        obj_tilegrid.vars.canvasUpdate = true -- mark canvas for update if any tile was updated
                    end
                end
                
            end
        end

    end,
    function() -- draw function
        if obj_tilegrid.vars.canvasUpdate then
            -- destroy old canvas
            Canvas.destroy(obj_tilegrid.vars.tileCanvas) -- destroy old canvas
            obj_tilegrid.vars.tileCanvas = Canvas.new() -- create a new canvas
            -- iterate over the grid and draw each tile onto the canvas
            for j = 1, obj_tilegrid.vars.gridHeight do
                for i = 1, obj_tilegrid.vars.gridWidth do
                    local tile = obj_tilegrid.vars.tileGrid[j][i]
                    local x = 256 / 2 - 16 * obj_tilegrid.vars.gridWidth / 2 + (i - 1) * obj_tilegrid.vars.tileSize
                    local y = obj_tilegrid.vars.y + (j - 1) * obj_tilegrid.vars.tileSize
                    -- draw tile sprite onto canvas
                    local cobj = Canvas.newImage(x,y,tile.spr) -- canvas object for this tile, default to the assigned sprite
                    
                    -- if  it is a road tile with enemies, change the sprite
                    if tile.type == "road" and #tile.data.enemies > 0 then
                       cobj = Canvas.newImage(x,y,obj_tilegrid.vars.tileSprites["road_enemies"]) -- use road with enemies sprite
                    end
                    Canvas.add(obj_tilegrid.vars.tileCanvas, cobj) -- add to canvas
                end
            end
            obj_tilegrid.vars.canvasUpdate = false -- reset canvas update flag
            
        end 
        Canvas.draw(SCREEN_DOWN, obj_tilegrid.vars.tileCanvas, obj_tilegrid.vars.x, obj_tilegrid.vars.y)   

        -- draw card slots
        -- one card has width of 16 pixels, 256 / 16 = 16 cards can fit in one row
        for i = 1, obj_tilegrid.vars.maxCards do
            local x = 256 / 2 - Usprites.CARD_WIDTH * obj_tilegrid.vars.maxCards / 2 + (i - 1) * Usprites.CARD_WIDTH
            local y = SCREEN_HEIGHT - Usprites.CARD_HEIGHT - 8 -- place cards at the bottom of the screen
            if i <= #obj_tilegrid.vars.heldCards then
                -- draw card sprite if it exists
                local card = obj_tilegrid.vars.heldCards[i]
                if card then
                    screen.blit(SCREEN_DOWN, x, y, card.spr, 0, 0, Usprites.CARD_WIDTH, Usprites.CARD_HEIGHT) -- draw card sprite
                end
            else
                -- draw empty slot
                screen.blit(SCREEN_DOWN, x, y, Usprites.spr_card_empty, 0, 0, Usprites.CARD_WIDTH, Usprites.CARD_HEIGHT) -- draw empty card slot
            end
        end

    end
)

-- call init function to initialize the tilegrid
obj_tilegrid.init()

-- create hero
obj_hero = createObject(
    Usprites.spr_hero,
    {
        currentRoadPathIndex = 1, -- index of the current road path tile
        startingTile = obj_tilegrid.vars.roadPath[1], -- starting tile for the hero
        x = obj_tilegrid.vars.roadPath[1].x * obj_tilegrid.vars.tileSize - 8, -- center the hero on the tile
        y = obj_tilegrid.vars.roadPath[1].y * obj_tilegrid.vars.tileSize - 8, -- center the hero on the tile
        WALKING_COOLDOWN = 10, -- frames to wait before moving again
        walkingCooldown = 10, -- frames to wait before moving again
        walkingSpeed = 1, -- pixels per frame
        -- Battle stats
        xp = 99, -- experience points
        loop = 1, -- current loop number
        level = 1, -- hero level
        health = 250,
        MAXHEALTH = 250, -- maximum health
        regeneration = 0.1, -- regen per step
        attack = 5,
        defense = 1,
        ATTACKCOOLDOWN = 30, -- frames to wait before attacking again
        attackCooldown = 30, -- frames to wait before attacking again
        getTileEnemies = function() -- function to get enemies on the current tile
            local currentX = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex].x
            local currentY = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex].y
            return obj_tilegrid.vars.tileGrid[currentY][currentX].data.enemies -- return enemies on the current tile
        end,
        calcLevelXPNeeded = function(level) -- calculate XP needed for next level
            return 100 + (level-1) * 50 -- simple formula for XP needed for next level
        end,
        -- Level up function
        levelUp = function()
            local thisLevelXP = obj_hero.vars.calcLevelXPNeeded(obj_hero.vars.level) -- calculate XP needed for this level
            obj_hero.vars.level = obj_hero.vars.level + 1 -- increase level
            obj_hero.vars.xp = obj_hero.vars.xp - thisLevelXP -- reset XP to the remainder
            obj_hero.vars.MAXHEALTH = obj_hero.vars.MAXHEALTH + 20 -- increase health
            obj_hero.vars.attack = obj_hero.vars.attack + 2 -- increase attack
            obj_hero.vars.defense = obj_hero.vars.defense + 1 -- increase defense
            -- heal the hero
            obj_hero.vars.health = obj_hero.vars.MAXHEALTH -- heal the hero to full health
        end,
        regenerateHealth = function() -- regenerate health
            obj_hero.vars.health = obj_hero.vars.health + obj_hero.vars.regeneration -- regenerate health
            if obj_hero.vars.health > obj_hero.vars.MAXHEALTH then
                obj_hero.vars.health = obj_hero.vars.MAXHEALTH -- cap health at max health
            end
        end,

    },
    function() -- init
        -- nothing to do here
    end, 
    function() -- update function
        if GAMESTATE.PAUSED == GS_PAUSED then
            return -- do not update if paused
        end
        if GAMESTATE.HEROSTATE == HS_WALKING then -- follow the path

            -- move hero along the road path
            obj_hero.vars.walkingCooldown = obj_hero.vars.walkingCooldown - obj_hero.vars.walkingSpeed
            if obj_hero.vars.walkingCooldown <= 0 then
                obj_hero.vars.regenerateHealth() -- regenerate health on each step
                -- move to next tile in path
                obj_hero.vars.currentRoadPathIndex = obj_hero.vars.currentRoadPathIndex + 1
                if obj_hero.vars.currentRoadPathIndex > #obj_tilegrid.vars.roadPath then --== At starting tile, regenerate HP
                    obj_hero.vars.currentRoadPathIndex = 1 -- loop back to start
                end
                -- get the next tile in the path
                local nextTile = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex]
                if nextTile then
                    obj_hero.vars.x = (nextTile.x * obj_tilegrid.vars.tileSize)  -- center the hero on the tile
                    obj_hero.vars.y = (nextTile.y * obj_tilegrid.vars.tileSize) -16 -- center the hero on the tile
                    obj_hero.vars.walkingCooldown = obj_hero.vars.WALKING_COOLDOWN -- reset cooldown
                    -- step on next tile
                    local ftile = obj_tilegrid.vars.tileGrid[nextTile.y][nextTile.x]
                    if ftile.enterFunc then
                        ftile.enterFunc(ftile) -- call enter function if it exists
                    end
                end
            end

        elseif GAMESTATE.HEROSTATE == HS_FIGHTING then -- fight the enemies
            local enemies = obj_hero.vars.getTileEnemies() -- get enemies on the current tile
            if #enemies == 0 then
                -- no enemies left, go back to walking state
                GAMESTATE.HEROSTATE = HS_WALKING
                obj_tilegrid.vars.canvasUpdate = true -- mark canvas for update as no enemies left
            else
                -- All enemies have an attack cooldown that decreases over time
                for i, enemy in ipairs(enemies) do
                    enemy.attackCooldown = enemy.attackCooldown - 1 -- decrement attack cooldown
                    if enemy.attackCooldown <= 0 then
                        -- attack the hero
                        obj_hero.vars.health = Umath.Round(obj_hero.vars.health - Umath.Clamp(enemy.attack - obj_hero.vars.defense, 0, enemy.attack - obj_hero.vars.defense+1),1) -- calculate damage
                        if obj_hero.vars.health <= 0 then
                            -- hero defeated, game over state
                            GAMESTATE.PAUSED = GS_GAMEOVER
                        end
                        enemy.attackCooldown = enemy.ATTACKCOOLDOWN -- reset attack cooldown
                    end
                end

                -- Hero attacks enemies
                obj_hero.vars.attackCooldown = obj_hero.vars.attackCooldown - 1 -- decrement attack cooldown
                -- the hero will always focus the first enemy in the list
                if obj_hero.vars.attackCooldown <= 0 and #enemies > 0 then
                    
                    obj_hero.vars.attackCooldown = obj_hero.vars.ATTACKCOOLDOWN -- reset attack cooldown
                    local enemy = enemies[1] -- focus the first enemy
                    enemy.health = enemy.health - Umath.Clamp(obj_hero.vars.attack - enemy.defense,0,obj_hero.vars.attack - enemy.defense+1) -- calculate damage
                    if enemy.health <= 0 then
                        -- enemy defeated, remove from tile
                        obj_hero.vars.xp = obj_hero.vars.xp + enemy.reward -- give XP to the hero
                        if obj_hero.vars.xp >= obj_hero.vars.calcLevelXPNeeded(obj_hero.vars.level) then
                            obj_hero.vars.levelUp() -- level up the hero
                        end
                        table.remove(enemies, 1) -- remove the first enemy
                       
                    end
                end

            end 
        end
    end,
    function() -- draw function
        --obj_hero.sprite:drawFrame(SCREEN_DOWN, obj_hero.vars.x, obj_hero.vars.y, 0) -- draw the hero sprite at the current position
        obj_hero.sprite:playAnimation(SCREEN_DOWN, obj_hero.vars.x, obj_hero.vars.y, 1) -- draw the hero sprite at the current position
        -- Draw health bar
        Gamegui.draw_bar_text(
                    8,
                    SCREEN_HEIGHT-16,
                    SCREEN_WIDTH/3,
                    10,
                    obj_hero.vars.health / obj_hero.vars.MAXHEALTH,
                    Gamegui.COLOR_RED, Gamegui.COLOR_GREEN, SCREEN_UP,
                    "Hero HP: "..obj_hero.vars.health.."/"..obj_hero.vars.MAXHEALTH) -- draw health bar


        Gamegui.draw_bar_text(
                    SCREEN_WIDTH/2,
                    SCREEN_HEIGHT-16,
                    SCREEN_WIDTH/3,
                    10,
                    obj_hero.vars.xp / obj_hero.vars.calcLevelXPNeeded(obj_hero.vars.level),
                    Gamegui.COLOR_BLUE, Gamegui.COLOR_GOLD, SCREEN_UP,
                    "XP: "..obj_hero.vars.xp.."/"..obj_hero.vars.calcLevelXPNeeded(obj_hero.vars.level).." (Lvl "..obj_hero.vars.level..")"
        )

        if GAMESTATE.HEROSTATE == HS_FIGHTING then
            -- Draw fighting UI or effects here
            screen.print(SCREEN_UP, 64,64,"Fighting enemies!")
            local currentX = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex].x
            local currentY = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex].y
            local currentTile = obj_tilegrid.vars.tileGrid[currentY][currentX]

            for i, _enemy in ipairs(currentTile.data.enemies) do
                screen.print(SCREEN_UP, 64, 75 + i * 8, "Enemy: ".._enemy.name.." HP: ".._enemy.health)
                -- Draw enemy sprite
                screen.blit(SCREEN_UP, 32, 75 + i * 8, _enemy.spr, 0,0,16,16) -- draw enemy sprite at a fixed position
            end
        end
        

    end
)

obj_hero.init() -- call init function to initialize the hero

-- Add objects to list, this is important to have manual depth sorting
table.insert(objList, obj_tilegrid)
table.insert(objList, obj_hero)

-- Update objects
function initGameObjects() -- calls init function for all objects
    for i, obj in ipairs(objList) do
        obj.init()
    end
end

function updateGameObjects() -- calls update function for all objects
    for i, obj in ipairs(objList) do
        obj.update()
    end
end

function drawGameObjects() -- calls draw function for all objects
    for i, obj in ipairs(objList) do
        obj.draw()
    end
end



--= Main Loop ==========--
while not Keys.newPress.Start do
    -- Update controls
    Controls.read()

    updateGameObjects()

    drawGameObjects()


    screen.print(SCREEN_UP, 0, 8, "Press START to quit - FPS: " .. NB_FPS)

    if obj_tilegrid.vars.selectedCard then
        screen.print(SCREEN_UP, 0, 16, "Selected Card: " .. obj_tilegrid.vars.selectedCard.cardData.name)
    else
        screen.print(SCREEN_UP, 0, 16, "No card selected")
    end

    -- Show gamestate
    if GAMESTATE.PAUSED == GS_PAUSED then
        screen.print(SCREEN_UP, 0, 24, "Game is paused. Tap a card to place it.")
    elseif GAMESTATE.PAUSED == GS_PLAYING then
        screen.print(SCREEN_UP, 0, 24, "Game is running. Tap a card to select it.")
    elseif GAMESTATE.PAUSED == GS_GAMEOVER then
        screen.print(SCREEN_UP, 0, 24, "Game Over! Press START to quit.")
    end

    render()
end
-- Free resources

Usprites.FreeSprites()