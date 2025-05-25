-- Loop Hero reimplementation for Nintendo DS Lua
Image = require("Image")

--= Global Variables ==========--
tmr = Timer.new()                   -- Create the timer
tmr:start()                          -- Start the timer
objList = {} -- list of objects
sprList = {} -- list of sprites
TARGET_FPS = 30
SEED = 123456789 -- Seed for random number generator

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

--= Math Functions ==========--

function random()
    -- Constants from Numerical Recipes LCG
    local seed = SEED
    seed = (1103515245 * seed + 12345) % 2147483648
    -- Update the global seed
    SEED = seed
    return (seed % 10000) / 10000  -- returns a float between 0.0 and 1.0
end

function floor(x)
    return x - (x % 1)
end

function randomRange(min, max)
    if max == nil then
        return min
    end
    return floor(random() * (max - min + 1) + min)
end

function randomChoice(t)
    return t[randomRange(1, #t)]
end

function randomInt(a, b)
    return a + floor(random() * (b - a + 1))
end

function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function copyShallow(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end


--= Path finding functions


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
    local start = edgeTiles[1]--randomChoice(edgeTiles)
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

    -- Shuffle helper using randomRange
    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = randomRange(1, i)
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


--= Enemy stats ==========--
spr_enemy_goblin = Image.load("goblin.png", VRAM) -- load goblin image
table.insert(sprList, spr_enemy_goblin) -- add to sprite list
E_GOBLIN = {
    name = "Goblin",
    health = 15,
    attack = 3,
    defense = 1,
    speed = 1,
    reward = 5, -- reward for defeating this enemy
    spr = spr_enemy_goblin,
    attackCooldown = 20, -- frames to wait before attacking again
    ATTACKCOOLDOWN = 20, -- frames to wait before attacking again
}

spr_enemy_slime = Image.load("slime.png", VRAM) -- load slime sprite
table.insert(sprList, spr_enemy_slime) -- add to sprite list
E_SLIME = {
    name = "Slime",
    health = 8,
    attack = 3,
    defense = 0,
    speed = 1,
    reward = 3, -- reward for defeating this enemy
    spr = spr_enemy_slime,
    attackCooldown = 35, -- frames to wait before attacking again
    ATTACKCOOLDOWN = 35, -- frames to wait before attacking again
}

--= Tile update functions ==========--
function updateRoadTile(tile) -- passing the tile for access to its properties
    -- spawn an enemy with a chance
    tile.data.spawnTimer = tile.data.spawnTimer - 1 -- decrement spawn timer
    if tile.data.spawnTimer <= 0 then
        tile.data.spawnTimer = randomRange(tile.data.minSpawnTimer, tile.data.maxSpawnTimer) -- reset spawn timer to a random value between 30 and 120 frames
        if random() < 0.1 then --spawn enemy
            if #tile.data.enemies == tile.data.maxEnemies then
                return false -- don't spawn if max enemies reached
            end
            local enemy = copyShallow(randomChoice({E_GOBLIN, E_SLIME})) -- create a copy of the goblin stats prototype
            table.insert(tile.data.enemies, enemy) -- add to the tile's enemies list
            return true -- indicate that the tile was updated
        end
    end
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
spr_tile_empty = Image.load("tile_empty.png", VRAM) -- load empty tile sprite
--spr_tile_empty = Sprite.new("tile_empty.png",16,16, VRAM)
table.insert(sprList, spr_tile_empty) -- add to sprite list
--spr_tile_empty:addAnimation({0},300) -- add animation for empty tile

spr_tile_road = Image.load("tile_road.png", VRAM) -- load road tile sprite
--spr_tile_road = Sprite.new("tile_road.png",16,16, VRAM)
table.insert(sprList, spr_tile_road) -- add to sprite list
--spr_tile_road:addAnimation({0},300) -- add animation for road tile

spr_tile_road_enemies = Image.load("tile_road_enemies.png", VRAM) -- load road tile with enemies sprite
--spr_tile_road_enemies = Sprite.new("tile_road_enemies.png",16,16, VRAM) -- tile with enemies on it
table.insert(sprList, spr_tile_road_enemies) -- add to sprite list
--spr_tile_road_enemies:addAnimation({0},300) -- add animation for road tile with enemies

obj_tilegrid = createObject(
    nil, -- no sprite
    {
        x=0,
        y=0,
        tileSize=16,
        gridWidth=14,
        gridHeight=8,
        tileGrid = {},
        tileSprites ={},
        tileCanvas = Canvas.new(), -- drawing onto canvas for performance
        canvasUpdate = true, -- flag to update canvas when needed
        roadPath = {}, -- this will hold the road path tiles in a sequence
        cardPlaceToGridcoords = function(sx, sy)
            -- calculate grid's left edge as in the draw function
            local grid_left = 256 / 2 - obj_tilegrid.vars.tileSize * obj_tilegrid.vars.gridWidth / 2
            local x = floor((sx - grid_left) / obj_tilegrid.vars.tileSize) + 1
            local y = floor((sy - obj_tilegrid.vars.y) / obj_tilegrid.vars.tileSize) + 1
            return x, y
        end
    },
    function() -- init grid to empty
        -- tile sprites
        obj_tilegrid.vars.tileSprites["empty"] = spr_tile_empty
        obj_tilegrid.vars.tileSprites["road"] = spr_tile_road
        obj_tilegrid.vars.tileSprites["road_enemies"] = spr_tile_road_enemies
        -- grid
        for j = 1, obj_tilegrid.vars.gridHeight do
            obj_tilegrid.vars.tileGrid[j] = {}
            for i = 1, obj_tilegrid.vars.gridWidth do
                obj_tilegrid.vars.tileGrid[j][i] = {
                    type = "empty",   -- could be "path", "grass", "road", etc.
                    occupied = false, -- is there a game object on this tile?
                    data = {
                        updateFunc = nil, -- function to call for updates (e.g., spawn timer)
                        enemies = {}, -- list of enemies on this tile
                        spawnTimer = 0, -- timer for spawning enemies or events
                        minSpawnTimer = 120,
                        maxSpawnTimer = 300, -- range for random spawn timer
                        maxEnemies = 3, -- maximum number of enemies that can spawn on this tile
                        spr = obj_tilegrid.vars.tileSprites["empty"], -- sprite to draw for this tile
                    }         -- custom data (e.g., spawn timer, event flags)
                }
            end
        end
        -- make a connected looping road path
        local generatedPath = randomPath()
        for _, pos in ipairs(generatedPath) do
            local x = pos.x
            local y = pos.y
            if inBounds(x, y, obj_tilegrid.vars.gridWidth, obj_tilegrid.vars.gridHeight) then -- assign road tile changes
                obj_tilegrid.vars.tileGrid[y][x].type = "road"
                table.insert(obj_tilegrid.vars.roadPath, {x = x, y = y})
                obj_tilegrid.vars.tileGrid[y][x].data.updateFunc = updateRoadTile -- assign the update function for road tiles
                obj_tilegrid.vars.tileGrid[y][x].data.spawnTimer = randomRange(obj_tilegrid.vars.tileGrid[y][x].data.minSpawnTimer, obj_tilegrid.vars.tileGrid[y][x].data.maxSpawnTimer) -- set initial spawn timer
                obj_tilegrid.vars.tileGrid[y][x].data.spr = obj_tilegrid.vars.tileSprites["road"] -- set the sprite for the road tile
            end
        end

    end, -- end init function
    function() -- update function
        if GAMESTATE.PAUSED == GS_PAUSED or GAMESTATE.HEROSTATE == HS_FIGHTING then
            return -- do not update if paused or in a fight state
        end

        -- update the tile grid
        for j = 1, obj_tilegrid.vars.gridHeight do
            for i = 1, obj_tilegrid.vars.gridWidth do
                local tile = obj_tilegrid.vars.tileGrid[j][i]
                if tile.type == "road" then
                    -- call the update function for the road tile
                    local shouldUpdate=tile.data.updateFunc(tile) -- passing the tile for access to its properties
                    if shouldUpdate then
                        obj_tilegrid.vars.canvasUpdate = true -- mark canvas for update if any tile was updated
                    end
                end
            end
        end
        -- If stylus is pressed, convert screen coordinates to grid coordinates
        if Stylus.held then
            local x, y = obj_tilegrid.vars.cardPlaceToGridcoords(Stylus.X, Stylus.Y) -- convert screen coordinates to grid coordinates
            if inBounds(x, y, obj_tilegrid.vars.gridWidth, obj_tilegrid.vars.gridHeight) then -- check bounds
                local tile = obj_tilegrid.vars.tileGrid[y][x]
                if not tile.occupied then -- if tile is not occupied
                    tile.type = "road" -- change tile type to road
                    tile.data.updateFunc = updateRoadTile -- assign the update function for road tiles
                    tile.data.spawnTimer = randomRange(tile.data.minSpawnTimer, tile.data.maxSpawnTimer) -- set initial spawn timer
                    tile.data.spr = obj_tilegrid.vars.tileSprites["road"] -- set the sprite for the road tile
                    
                    obj_tilegrid.vars.canvasUpdate = true -- mark canvas for update
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
                    local cobj = Canvas.newImage(x,y,tile.data.spr) -- canvas object for this tile, default to the assigned sprite
                    
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
    end
)

-- call init function to initialize the tilegrid
obj_tilegrid.init()

-- create hero
spr_hero = Sprite.new("hero.png",16,16, VRAM)
spr_hero:addAnimation({0,1},300)
table.insert(sprList, spr_hero) -- add to sprite list
obj_hero = createObject(
    spr_hero,
    {
        currentRoadPathIndex = 1, -- index of the current road path tile
        startingTile = obj_tilegrid.vars.roadPath[1], -- starting tile for the hero
        x = obj_tilegrid.vars.roadPath[1].x * obj_tilegrid.vars.tileSize - 8, -- center the hero on the tile
        y = obj_tilegrid.vars.roadPath[1].y * obj_tilegrid.vars.tileSize - 8, -- center the hero on the tile
        WALKING_COOLDOWN = 10, -- frames to wait before moving again
        walkingCooldown = 10, -- frames to wait before moving again
        walkingSpeed = 1, -- pixels per frame
        -- Battle stats
        health = 100,
        attack = 5,
        defense = 2,
        ATTACKCOOLDOWN = 45, -- frames to wait before attacking again
        attackCooldown = 45, -- frames to wait before attacking again
        getTileEnemies = function() -- function to get enemies on the current tile
            local currentX = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex].x
            local currentY = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex].y
            return obj_tilegrid.vars.tileGrid[currentY][currentX].data.enemies -- return enemies on the current tile
        end,

    },
    function() -- init
        -- nothing to do here
    end, 
    function() -- update function
        if GAMESTATE.HEROSTATE == HS_WALKING then -- follow the path

            -- move hero along the road path
            obj_hero.vars.walkingCooldown = obj_hero.vars.walkingCooldown - obj_hero.vars.walkingSpeed
            if obj_hero.vars.walkingCooldown <= 0 then
                -- move to next tile in path
                obj_hero.vars.currentRoadPathIndex = obj_hero.vars.currentRoadPathIndex + 1
                if obj_hero.vars.currentRoadPathIndex > #obj_tilegrid.vars.roadPath then
                    obj_hero.vars.currentRoadPathIndex = 1 -- loop back to start
                end

                local nextTile = obj_tilegrid.vars.roadPath[obj_hero.vars.currentRoadPathIndex]
                if nextTile then
                    obj_hero.vars.x = (nextTile.x * obj_tilegrid.vars.tileSize)  -- center the hero on the tile
                    obj_hero.vars.y = (nextTile.y * obj_tilegrid.vars.tileSize) -16 -- center the hero on the tile
                    obj_hero.vars.walkingCooldown = obj_hero.vars.WALKING_COOLDOWN -- reset cooldown
                    -- does it have enemies?
                    -- first resolve the actual tile from the position
                    local ftile = obj_tilegrid.vars.tileGrid[nextTile.y][nextTile.x]
                    if ftile.type == "road" and #ftile.data.enemies > 0 then
                        -- start fighting state, reset attack cooldown each combat
                        GAMESTATE.HEROSTATE = HS_FIGHTING
                        obj_hero.vars.attackCooldown = obj_hero.vars.ATTACKCOOLDOWN -- reset attack cooldown
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
                        obj_hero.vars.health = obj_hero.vars.health - clamp(enemy.attack - obj_hero.vars.defense, 0, enemy.attack - obj_hero.vars.defense+1) -- calculate damage
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
                    enemy.health = enemy.health - clamp(obj_hero.vars.attack - enemy.defense,0,obj_hero.vars.attack - enemy.defense+1) -- calculate damage
                    if enemy.health <= 0 then
                        -- enemy defeated, remove from tile
                        table.remove(enemies, 1) -- remove the first enemy
                       
                    end
                end

            end 
        end
    end,
    function() -- draw function
        --obj_hero.sprite:drawFrame(SCREEN_DOWN, obj_hero.vars.x, obj_hero.vars.y, 0) -- draw the hero sprite at the current position
        obj_hero.sprite:playAnimation(SCREEN_DOWN, obj_hero.vars.x, obj_hero.vars.y, 1) -- draw the hero sprite at the current position
        screen.print(SCREEN_UP, 64, 180, "Hero HP: "..obj_hero.vars.health)

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


    screen.print(SCREEN_UP, 0, 8, "Press START to quit")
    screen.print(SCREEN_UP, 0, 16, "FPS: "..NB_FPS)
    render()
end
-- Free resources
for i,s in ipairs(sprList) do -- this should theoretically free all images 
    -- check if it is an Image or a Sprite
    if s.destroy then
        s:destroy() -- destroy sprite or image
    else
        Image.destroy(s) -- destroy image
    end
end
