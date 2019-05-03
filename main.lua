-- Render constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
local RENDER_SCALE = 3

-- Game constants
local LEVEL_COLUMNS = 12
local LEVEL_ROWS = 12
local TILE_TYPES = {
  -- Grass
  ['.'] = { sprite = 1 },
  [','] = { sprite = 2 },
  -- Trees
  ['T'] = { sprite = 3, isImpassable = true },
  ['F'] = { sprite = 4, isImpassable = true },
  -- Cliffs
  ['I'] = { sprite = 5, isImpassable = true },
  ['L'] = { sprite = 6, isImpassable = true },
  ['M'] = { sprite = 7, isImpassable = true },
  -- House
  ['H'] = { sprite = 8, isPortal = true, url = 'https://raw.githubusercontent.com/schazers/ghost-racer/master/main.lua' },
  ['W'] = { sprite = 8, isPortal = true, url = 'https://raw.githubusercontent.com/schazers/wat-dont/master/main.lua' },
  -- Path
  ['~'] = { sprite = 9 },
  -- Lake
  ['1'] = { sprite = 10, isImpassable = true },
  ['2'] = { sprite = 11, isImpassable = true },
  ['3'] = { sprite = 12, isImpassable = true },
  ['4'] = { sprite = 13, isImpassable = true },
  ['5'] = { sprite = 14, isImpassable = true },
  ['6'] = { sprite = 15, isImpassable = true },
  ['7'] = { sprite = 16, isImpassable = true },
  -- Key
  ['K'] = { sprite = 'key' },
  -- Gate
  ['G'] = { sprite = 'gate', isImpassable = true }
}

local LEVEL_DATA = {
{
worldPosX = 0,
worldPosY = 0,
mapData = [[
FFTTI,.FT,FT
TFF.LMMMIT.F
.T.,.T.,LMMM
F,....,,....
...,..,15555
~~..,..36666
,..,..,26676
FF.,..,,2444
.F,T,....,.,
T.F,,F,.,,..
TF,F.TF.F.,T
FTT.TFFTTFTF
]],
},
{
worldPosX = -1,
worldPosY = 0,
mapData = [[
..TTFT.FT.,T
TFF...TFFTTF
.T.,.T.,...T
F,....,,...T
F....K,.....
TTF.,H...~~~
FT.,..,.....
T..,..,,...F
FT,T,....,TF
T.F,FFTT.F.T
TF,F.TFFFFTT
FTT.T,T.TFTF
]],
},
{
worldPosX = 1,
worldPosY = 0,
mapData = [[
..TTFT.FT.W.
TFF...T.F...
...,..,.FGFT
...,..,.,.,F
555555555555
676666666676
666676666666
444444444444
,..,.F.,,.FF
..,.,T..F,T,
T.F,FFTT.TFT
TF,F.TFFFFTT
]],
}
}

-- Game variables
local player
local tileGrid
local currMapIdx = 1
local kartPortal = nil
local hasKey = false
local shouldShowKey = false
local gateLocked = true

-- Assets
local playerImage
local tilesImage
local keyImage
local gateImage
local moveSound
local bumpSound
local keySound
local gateSound

-- Get referring game data
local referrer = castle.game.getReferrer()
local referrerTitle = referrer and referrer.title or '<no referrer>'
local initialParams = castle.game.getInitialParams()
local msgFromReferrer = initialParams and initialParams.msg or '<no msg>'

-- Initialize the game
function love.load()
  -- Load assets
  playerImage = love.graphics.newImage('img/player.png')
  tilesImage = love.graphics.newImage('img/tiles.png')
  keyImage = love.graphics.newImage('img/key.png')
  gateImage = love.graphics.newImage('img/gate.png')
  playerImage:setFilter('nearest', 'nearest')
  tilesImage:setFilter('nearest', 'nearest')
  keyImage:setFilter('nearest', 'nearest')
  gateImage:setFilter('nearest', 'nearest')
  moveSound = love.audio.newSource('sfx/move.wav', 'static')
  bumpSound = love.audio.newSource('sfx/bump.wav', 'static')
  keySound = love.audio.newSource('sfx/key.mp3', 'static')
  gateSound = love.audio.newSource('sfx/gate.mp3', 'static')

  -- Create the player
  player = {
    col = 6,
    row = 6,
    facing = 'down'
  }

  -- TODO(jason): init player where they should be based upon that game
  -- and make a key appear on the ground for them to pick up. add a simple 
  -- inventory to the adventure character?
  if referrer ~= nil then
    print("referrerTitle: "..referrerTitle)
    print("message received: "..msgFromReferrer)
    currMapIdx = 2
    player.col = 7
    player.row = 6
    shouldShowKey = true
  end

  -- Create the level
  updateMapData()
end

-- Update map data
function updateMapData()
  tileGrid = {}
  for col = 1, LEVEL_COLUMNS do
    tileGrid[col] = {}
    for row = 1, LEVEL_ROWS do
      local i = (LEVEL_ROWS + 1) * (row - 1) + col
      local symbol = string.sub(LEVEL_DATA[currMapIdx]['mapData'], i, i)
      tileGrid[col][row] = TILE_TYPES[symbol]
    end
  end
end

-- Render the game
function love.draw()

  -- Scale and crop the screen
  love.graphics.setScissor(0, 0, RENDER_SCALE * GAME_WIDTH, RENDER_SCALE * GAME_HEIGHT)
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)

  -- Draw the tiles
  for col = 1, LEVEL_COLUMNS do
    for row = 1, LEVEL_ROWS do
      if tileGrid[col][row] then
        if tileGrid[col][row].sprite == 'gate' then
          drawSprite(tilesImage, 16, 16, 1, calculateRenderPosition(col, row))
          if gateLocked then
            drawSprite(gateImage, 16, 16, 1, calculateRenderPosition(col, row))
          end
        elseif tileGrid[col][row].sprite == 'key' then
          drawSprite(tilesImage, 16, 16, 1, calculateRenderPosition(col, row))
          if shouldShowKey and not hasKey then
            drawSprite(keyImage, 16, 16, 1, calculateRenderPosition(col, row))
          end
        else
          drawSprite(tilesImage, 16, 16, tileGrid[col][row].sprite, calculateRenderPosition(col, row))
        end
      end
    end
  end

  -- Draw the player
  local sprite
  if player.facing == 'down' then
    sprite = 1
  elseif player.facing == 'up' then
    sprite = 3
  else
    sprite = 2
  end
  local x, y = calculateRenderPosition(player.col, player.row)
  drawSprite(playerImage, 16, 16, sprite, x, y, player.facing == 'left')
  if hasKey then
    drawSprite(keyImage, 16, 16, 1, x, y)
  end
end

-- Press arrow keys to move the player
function love.keypressed(key)

  -- Figure out which tile is being moved into
  local col, row = player.col, player.row
  if key == 'up' or key == 'w' then
    row = row - 1
    player.facing = 'up'
  elseif key == 'left' or key == 'a' then
    col = col - 1
    player.facing = 'left'
  elseif key == 'down' or key == 's' then
    row = row + 1
    player.facing = 'down'
  elseif key == 'right' or key == 'd' then
    col = col + 1
    player.facing = 'right'
  end
  -- Figure out if the player can move into that tile
  local canMoveIntoTile = true
  if col < 1 then
    if currMapIdx == 1 then 
      currMapIdx = 2
    elseif currMapIdx == 3 then
      currMapIdx = 1
    end
    col = LEVEL_COLUMNS
    updateMapData()
  elseif col > LEVEL_COLUMNS then
    if currMapIdx == 2 then 
      currMapIdx = 1
    elseif currMapIdx == 1 then
      currMapIdx = 3
    end
    col = 1
    updateMapData()
  elseif row < 1 or row > LEVEL_ROWS then
    canMoveIntoTile = false
  else
    local tile = tileGrid[col][row]
    if tile.sprite == 'gate' and hasKey then
      tile.isImpassable = false
    end
    if tile and tile.isImpassable then
      canMoveIntoTile = false
    end
  end
  -- Move the player
  if col ~= player.col or row ~= player.row then
    if canMoveIntoTile then
      player.col, player.row = col, row
      if tileGrid[col][row].isPortal then
        -- TODO(jason): play a warping sound?
        network.async(function()
          -- Refer by URL here, other game uses `gameId`
          castle.game.load(
            tileGrid[col][row].url, {
              msg = 'Message received from castle-adventure',
            }
          )
        end)
      elseif tileGrid[col][row].sprite == 'key' and not hasKey then
        hasKey = true
        shouldShowKey = false
        love.audio.play(keySound:clone())
      elseif tileGrid[col][row].sprite == 'gate' and hasKey then
        gateLocked = false
        hasKey = false
        love.audio.play(gateSound:clone())
      else
        love.audio.play(moveSound:clone())
      end
    else
      love.audio.play(bumpSound:clone())
    end
  end
end

-- Takes in a column and a row and returns the corresponding x,y coordinates
function calculateRenderPosition(col, row)
  return 16 * (col - 1), 16 * (row - 1)
end

-- Draws a sprite from a sprite sheet, spriteNum=1 is the upper-leftmost sprite
function drawSprite(spriteSheetImage, spriteWidth, spriteHeight, sprite, x, y, flipHorizontal, flipVertical, rotation)
  local width, height = spriteSheetImage:getDimensions()
  local numColumns = math.floor(width / spriteWidth)
  local col, row = (sprite - 1) % numColumns, math.floor((sprite - 1) / numColumns)
  love.graphics.draw(spriteSheetImage,
    love.graphics.newQuad(spriteWidth * col, spriteHeight * row, spriteWidth, spriteHeight, width, height),
    x + spriteWidth / 2, y + spriteHeight / 2,
    rotation or 0,
    flipHorizontal and -1 or 1, flipVertical and -1 or 1,
    spriteWidth / 2, spriteHeight / 2)
end
