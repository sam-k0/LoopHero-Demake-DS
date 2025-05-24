-- Loop Hero reimplementation for Nintendo DS Lua
Image = require("Image")

--= Global Variables ==========--
tmr = Timer.new()                   -- Create the timer
tmr:start()                          -- Start the timer
objList = {} -- list of objects
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

spr_hero = Image.load("hero.png", VRAM)
-- create hero
obj_hero = createObject(
    createSprite(spr_hero, 16, 16, 2, 10, SCREEN_DOWN),
    {
        x=0,
        y=0
    },
    function() -- init
        -- nothing to do here
    end, 
    function() -- update function
        updateSpriteAnimation(obj_hero.sprite)

        if Keys.held.Up then obj_hero.vars.y = obj_hero.vars.y - 2 end
        if Keys.held.Down then obj_hero.vars.y = obj_hero.vars.y + 2 end
        if Keys.held.Right then obj_hero.vars.x = obj_hero.vars.x + 2 end
        if Keys.held.Left then obj_hero.vars.x = obj_hero.vars.x - 2 end
    end,
    function() -- draw function
        drawSpriteAnimation(obj_hero.sprite.scrn, obj_hero.sprite, obj_hero.vars.x, obj_hero.vars.y)
    end
)

-- create tilegrid manager
spr_tile_empty = Image.load("tile_empty.png", VRAM)
spr_tile_road = Image.load("tile_road.png", VRAM)

obj_tilegrid = createObject(
    nil, -- no sprite
    {
        x=256 / 2 - 16 * 5,
        y=0,
        tileSize=16,
        gridWidth=10,
        gridHeight=10,
        tileGrid = {},
        tileSprites ={}
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
        for j = 1, obj_tilegrid.vars.gridHeight do
            for i = 1, obj_tilegrid.vars.gridWidth do
                if (i == 1 or i == obj_tilegrid.vars.gridWidth) and (j == 1 or j == obj_tilegrid.vars.gridHeight) then
                    obj_tilegrid.vars.tileGrid[j][i].type = "road"
                elseif (i == 1 or i == obj_tilegrid.vars.gridWidth) then
                    obj_tilegrid.vars.tileGrid[j][i].type = "road"
                elseif (j == 1 or j == obj_tilegrid.vars.gridHeight) then
                    obj_tilegrid.vars.tileGrid[j][i].type = "road"
                end
            end
        end 

    end,
    function() -- update function
        -- nothing to do here
    end,
    function() -- draw function
        -- iterate over the grid and draw each tile starting at anchor point x,y
        for j = 1, obj_tilegrid.vars.gridHeight do
            for i = 1, obj_tilegrid.vars.gridWidth do
                local tile = obj_tilegrid.vars.tileGrid[j][i]
                local x = obj_tilegrid.vars.x + (i - 1) * obj_tilegrid.vars.tileSize
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
initGameObjects()

while not Keys.newPress.Start do
    -- Update controls
    Controls.read()

    updateGameObjects()

    drawGameObjects()


    screen.print(SCREEN_UP, 0, 8, "Press START to quit")

    render()
end
-- Free resources
Image.destroy(spr_hero)
