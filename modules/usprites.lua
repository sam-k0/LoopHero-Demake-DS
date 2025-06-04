local Image = require("Image")

local usprites = {}


usprites.CARD_WIDTH = 16 -- width of a card in pixels
usprites.CARD_HEIGHT = 22 -- height of a card in pixels

usprites.sprList = {} -- List to hold all sprites

usprites.spr_enemy_goblin = Image.load("gameassets/goblin.png", VRAM) -- load goblin image
table.insert(usprites.sprList, usprites.spr_enemy_goblin) -- add to sprite list

usprites.spr_enemy_slime = Image.load("gameassets/slime.png", VRAM) -- load slime sprite
table.insert(usprites.sprList, usprites.spr_enemy_slime) -- add to sprite list

usprites.spr_tile_empty = Image.load("gameassets/tile_empty.png", VRAM) -- load empty tile sprite
table.insert(usprites.sprList, usprites.spr_tile_empty) -- add to sprite list

usprites.spr_tile_road = Image.load("gameassets/tile_road.png", VRAM) -- load road tile sprite
table.insert(usprites.sprList, usprites.spr_tile_road) -- add to sprite list

usprites.spr_tile_road_camp = Image.load("gameassets/tile_road_camp.png", VRAM) -- load road tile with camp sprite
table.insert(usprites.sprList, usprites.spr_tile_road_camp) -- add to sprite list

usprites.spr_tile_road_enemies = Image.load("gameassets/tile_road_enemies.png", VRAM) -- load road tile with enemies sprite
table.insert(usprites.sprList, usprites.spr_tile_road_enemies) -- add to sprite list

usprites.spr_tile_mountain = Image.load("gameassets/tile_mountain.png", VRAM) -- load mountain tile sprite
table.insert(usprites.sprList, usprites.spr_tile_mountain) -- add to sprite list

usprites.spr_tile_meadow = Image.load("gameassets/tile_meadow.png", VRAM) -- load meadow tile sprite
table.insert(usprites.sprList, usprites.spr_tile_meadow) -- add to sprite list

--== Create Card images ==========--
usprites.spr_card_empty = Image.load("gameassets/card_empty.png", VRAM) -- load empty card sprite
table.insert(usprites.sprList, usprites.spr_card_empty) -- add to sprite list
usprites.spr_card_mountain = Image.load("gameassets/card_mountain.png", VRAM) -- load mountain card sprite
table.insert(usprites.sprList, usprites.spr_card_mountain) -- add to sprite list
usprites.spr_card_meadow = Image.load("gameassets/card_meadow.png", VRAM) -- load meadow card sprite
table.insert(usprites.sprList, usprites.spr_card_meadow) -- add to sprite list

usprites.spr_hero = Sprite.new("gameassets/hero.png",16,16, VRAM)
usprites.spr_hero:addAnimation({0,1},300)
table.insert(usprites.sprList, usprites.spr_hero) -- add to sprite list

function usprites.FreeSprites()
    for i,s in ipairs(usprites.sprList) do -- this should theoretically free all images 
        -- check if it is an Image or a Sprite
        if s.destroy then
            s:destroy() -- destroy sprite or image
        else
            Image.destroy(s) -- destroy image
        end
    end
        usprites.sprList = {} -- clear the sprite list
end


return usprites