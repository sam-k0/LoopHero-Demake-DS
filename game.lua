-- Loop Hero reimplementation for Nintendo DS Lua
Image = require("Image")

--= Global Variables ==========--
tmr = Timer.new()                   -- Create the timer
tmr:start()                          -- Start the timer

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

function createObject(sprAnim,varTable, updateFunc, drawFunc ) -- object is basically a sprite with an update function to take care of vars
    return {
        sprite = sprAnim,
        vars = varTable,
        update = updateFunc,
        draw = drawFunc
    }
end

spr_hero = Image.load("hero.png", VRAM)

obj_hero = createObject(
    createSprite(spr_hero, 16, 16, 2, 10, SCREEN_DOWN),
    {
        x=0,
        y=0
    }, 
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

-- Update objects
objList = {}
table.insert(objList, obj_hero)

function updateGameObjects()
    for i, obj in ipairs(objList) do
        obj.update()
    end
end

function drawGameObjects()
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

    render()
end
-- Free resources
Image.destroy(spr_hero)
