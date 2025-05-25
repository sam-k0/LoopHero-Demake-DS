-- Loop Hero reimplementation for Nintendo DS Lua
Image = require("Image")

--= Global Variables ==========--
tmr = Timer.new()                   -- Create the timer
tmr:start()                          -- Start the timer
objList = {} -- list of objects
sprList = {} -- list of sprites, added onto by createSprite
TARGET_FPS = 30
DELTA_TIME = 1/TARGET_FPS
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
    return (seed % 10000) / 10000  -- returns a float between 0.0 and 1.0
end

function randomRange(min, max)
    return math.floor(random() * (max - min + 1) + min)
end

function randomChoice(t)
    return t[randomRange(1, #t)]
end

function randomInt(a, b)
    return a + math.floor(random() * (b - a + 1))
end

function floor(x)
    return x - (x % 1)
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
    local start = randomChoice(edgeTiles)
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




--= Animation Functions ==========--

function updateSpriteAnimation(anim) -- updates the animation frame
    anim.frameCounter = anim.frameCounter + 1
    if anim.frameCounter >= anim.frameDelay then
        anim.currentFrame = anim.currentFrame + 1
        if anim.currentFrame > anim.frameCount then
            anim.currentFrame = 1
        end
        anim.frameCounter = 0
    end
end

function drawSpriteAnimation(scrn, anim, x, y) -- draws the current frame of the animation
    local sx = (anim.currentFrame - 1) * anim.frameWidth
    local sy = 0
    screen.blit(scrn, x, y, anim.image, sx, sy, anim.frameWidth, anim.frameHeight)
end


--= Create objects ==========--
function createSprite(img,fw, fh, fc, fd, scrn) -- creates table with sprite properties
    table.insert(sprList,img)
    return {
        image = img,
        frameWidth = fw,
        frameHeight = fh,
        frameCount = fc,
        currentFrame = 1,
        frameDelay = fd, -- frames to wait before switching
        frameCounter = 0,
        scrn = SCREEN_DOWN
    }
end


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
spr_tile_empty = Image.load("tile_empty.png", VRAM)
spr_tile_road = Image.load("tile_road.png", VRAM)

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
        roadPath = {} -- this will hold the road path tiles in a sequence
    },
    function() -- init grid to empty
        -- tile sprites
        obj_tilegrid.vars.tileSprites["empty"] = createSprite(spr_tile_empty, 16, 16, 1, 10, SCREEN_DOWN)
        obj_tilegrid.vars.tileSprites["road"] = createSprite(spr_tile_road, 16, 16, 1, 10, SCREEN_DOWN)
        -- grid
        for j = 1, obj_tilegrid.vars.gridHeight do
            obj_tilegrid.vars.tileGrid[j] = {}
            for i = 1, obj_tilegrid.vars.gridWidth do
                obj_tilegrid.vars.tileGrid[j][i] = {
                    type = "empty",   -- could be "path", "grass", "road", etc.
                    occupied = false, -- is there a game object on this tile?
                    data = {}         -- custom data (e.g., spawn timer, event flags)
                }
            end
        end
        -- make a connected looping road path
        local generatedPath = randomPath()
        for _, pos in ipairs(generatedPath) do
            local x = pos.x
            local y = pos.y
            if inBounds(x, y, obj_tilegrid.vars.gridWidth, obj_tilegrid.vars.gridHeight) then
                obj_tilegrid.vars.tileGrid[y][x].type = "road"
                table.insert(obj_tilegrid.vars.roadPath, {x = x, y = y})
            end
        end

    end, -- end init function
    function() -- update function
        -- nothing to do here
    end,
    function() -- draw function
        -- iterate over the grid and draw each tile starting at anchor point x,y
        for j = 1, obj_tilegrid.vars.gridHeight do
            for i = 1, obj_tilegrid.vars.gridWidth do
                local tile = obj_tilegrid.vars.tileGrid[j][i]
                local x = 256 / 2 - 16 * obj_tilegrid.vars.gridWidth / 2 + (i - 1) * obj_tilegrid.vars.tileSize
                local y = obj_tilegrid.vars.y + (j - 1) * obj_tilegrid.vars.tileSize
                if tile.type == "empty" then
                    drawSpriteAnimation(SCREEN_DOWN, obj_tilegrid.vars.tileSprites["empty"], x, y)
                elseif tile.type == "road" then
                    drawSpriteAnimation(SCREEN_DOWN, obj_tilegrid.vars.tileSprites["road"], x, y)
                end
            end
        end

    end
)

-- call init function to initialize the tilegrid
obj_tilegrid.init()

-- create hero
spr_hero = Image.load("hero.png", VRAM)
obj_hero = createObject(
    createSprite(spr_hero, 16, 16, 2, 10, SCREEN_DOWN),
    {
        currentRoadPathIndex = 1, -- index of the current road path tile
        startingTile = obj_tilegrid.vars.roadPath[1], -- starting tile for the hero
        x = obj_tilegrid.vars.roadPath[1].x * obj_tilegrid.vars.tileSize - 8, -- center the hero on the tile
        y = obj_tilegrid.vars.roadPath[1].y * obj_tilegrid.vars.tileSize - 8, -- center the hero on the tile
        WALKING_COOLDOWN = 10, -- frames to wait before moving again
        walkingCooldown = 10, -- frames to wait before moving again
        walkingSpeed = 1, -- pixels per frame
        
    },
    function() -- init
        -- nothing to do here
    end, 
    function() -- update function
        if GAMESTATE.HEROSTATE == HS_WALKING then -- follow the path
            updateSpriteAnimation(obj_hero.sprite) -- animate

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
                end
            end

        end
    end,
    function() -- draw function
        drawSpriteAnimation(obj_hero.sprite.scrn, obj_hero.sprite, obj_hero.vars.x, obj_hero.vars.y)
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
tmr:start()

while not Keys.newPress.Start do

    DELTA_TIME = tmr:getTime() -- get time since last frame
    tmr:reset() -- reset timer


    -- Update controls
    Controls.read()

    updateGameObjects()

    drawGameObjects()


    screen.print(SCREEN_UP, 0, 8, "Press START to quit")
    screen.print(SCREEN_UP, 0, 16, "FPS: "..NB_FPS)
    screen.print(SCREEN_UP, 0, 24, "Delta Time: "..DELTA_TIME)

    render()
end
-- Free resources
for i,s in ipairs(sprList) do -- this should theoretically free all images 
    if s.img then
        Image.free(s.img)
    end
    s.img = nil
end
