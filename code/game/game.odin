package main

import MATH       "core:math"
import MEM        "core:mem"
import FMT        "core:fmt"

import game "./definitions/"

/* NOTE(Carbon) Compiler flags
  
SLOW:
  false: No slow code allowed 
  true: slow code allowed

INTERNAL:
  false: Build for public
  true: Build for Developer

PRINT:
  false: Stops print statments
  true: turns on print statements

*/

//DEFINITION FOR DEBUG FUNCTIONS


//TODO(Carbon) is there a better way?

// For Timing, controls input, bitmap buffer, and sound buffer.
// TODO: Controls, Bitmap, Sound Buffer
@export
gameUpdateAndRender :: proc(thread: ^game.thread_context,
                            gameMemory:   ^game.memory, 
                            colorBuffer : ^game.offscreen_buffer, 
                            gameControls: ^game.input) {
                        //TODO(Carbon): Pass Time

  using game 
  when #config(SLOW, true) {
    assert(size_of(game.state) <= gameMemory.permanentStorageSize, "Game state to large for memory")
  }

  gameState := cast(^game.state)(gameMemory.permanentStorage)


  tiles00 := []u32{
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1 ,
  }
  tiles01 := []u32{
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1 ,
    0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1 ,
  }
  tiles10 := []u32{
    1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ,
  }
  tiles11 := []u32{
    1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1 ,
    0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1 ,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ,
  }


  tileMaps : [2][2]tile_map

  tileMaps[0][0].tiles = cast([^]u32)&tiles00[0]
  tileMaps[0][1].tiles = cast([^]u32)&tiles01[0]

  tileMaps[1][0].tiles = cast([^]u32)&tiles10[0]

  tileMaps[1][1].tiles = cast([^]u32)&tiles11[0]

  world : world_map
  world.tileMapCountX = 2
  world.tileMapCountY = 2
  world.tileMaps = cast([^]tile_map)&tileMaps[0][0]
  world.tileCountX = 16
  world.tileCountY = 9
  world.upperLeftX = 0.0
  world.upperLeftY = 0.0
  world.tileWidth = f32(colorBuffer.width / world.tileCountX)
  world.tileHeight = f32(colorBuffer.height / world.tileCountY)



  if !gameMemory.isInitialized {
    gameMemory.isInitialized = true
    gameState.player[.x] = 100
    gameState.player[.y] = 300
  }

  tileMap := getTileMap(&world, gameState.playerTile[.x], gameState.playerTile[.y])
  
  playerR, playerG, playerB : f32 = 0.0, 1.0, 0.0
  playerWidth  := 0.75 * world.tileWidth
  playerHeight := world.tileHeight
  playerLeft   := gameState.player[.x] - (0.5 * playerWidth)
  playerTop    := gameState.player[.y] - playerHeight

  for controller in gameControls.controllers {

    if !controller.isConnected do continue

    if(controller.isAnalog) {
      if controller.buttons[.action_down].endedDown {
        gameState.player[.x] = 100
        gameState.player[.y] = 300
      }
    } else {

      playerDX, playerDY : f32 = 0.0, 0.0

      if controller.buttons[.move_up].endedDown    do playerDY = -200.0
      if controller.buttons[.move_down].endedDown  do playerDY = 200.0
      if controller.buttons[.move_left].endedDown  do playerDX = -200.0
      if controller.buttons[.move_right].endedDown do playerDX = 200.0

      playerXNew := gameState.player[.x] + (playerDX * gameControls.dtPerFrame)
      playerYNew := gameState.player[.y] + (playerDY * gameControls.dtPerFrame)

      playerPos : raw_position = {
        gameState.playerTile[.x], gameState.playerTile[.y], playerXNew, playerYNew
      }
      playerLeft := playerPos
      playerLeft.pixelX -= 0.5 * playerWidth
      playerRight := playerPos
      playerRight.pixelX += 0.5 * playerWidth

      if (isWorldPointEmpty(&world, playerPos) &&
          isWorldPointEmpty(&world, playerLeft) &&
          isWorldPointEmpty(&world, playerRight) ){ 
        
        canPos := getCononicalPosition(&world, playerPos)
        gameState.playerTile[.x] = canPos.tileMapX
        gameState.playerTile[.y] = canPos.tileMapY
        gameState.player[.x] = world.upperLeftX + (world.tileWidth  * f32(canPos.tileX)) + canPos.pixelX
        gameState.player[.y] = world.upperLeftY + (world.tileHeight * f32(canPos.tileY)) + canPos.pixelY 
      }

    }
  }


  //clear screen
  drawRectangle(colorBuffer, 1.0, 0.0, 1.0,
                0, 0, f32(colorBuffer.width), f32(colorBuffer.height))


  for y : i32 = 0; y < world.tileCountY; y += 1 { 
    for x : i32 = 0; x < world.tileCountX; x += 1 {
      tile := getTileValueUnchecked(tileMap, &world, x, y)
      distanceX := (f32(x) * world.tileWidth) + world.upperLeftX 
      distanceY := (f32(y) * world.tileHeight) + world.upperLeftY 
      drawRectangle(colorBuffer, f32(tile), f32(tile), f32(tile),
                    distanceX,   distanceY, 
                    distanceX + world.tileWidth, distanceY + world.tileHeight)
    }
  }

  //draw player
  drawRectangle(colorBuffer, playerR, playerG, playerB,
                playerLeft, playerTop, 
                playerLeft + playerWidth, playerTop + playerHeight)

}

@export
gameGetSoundSamples :: proc(thread: ^game.thread_context,
                            memory: ^game.memory,
                            soundBuffer: ^game.sound_output_buffer) {
  gameState := cast(^game.state) memory.permanentStorage
  playbackTime := 1.0
  //NOTE(Carbon): Constants are Hz, Vol, multiplier (For mute)
  gameOutputSound(soundBuffer, 400, 1000, 0, &playbackTime )
}

@private
gameOutputSound :: proc(soundBuffer: ^game.sound_output_buffer, 
                        toneHz: u32, toneVolume, toneMulti: u16,
                        playbackTime: ^f64) {

  wavePeriod := soundBuffer.samplesPerSecond/toneHz
  buffer     := soundBuffer.samples 

  for frameIndex := 0; frameIndex < soundBuffer.sampleCount * 2; frameIndex += 2 {
    amp := f64(toneVolume) * MATH.sin(playbackTime^) * f64(toneMulti) 
    buffer[frameIndex] = i16(amp)
    buffer[frameIndex + 1] = i16(amp)
    playbackTime^ += 6.28 / f64(wavePeriod)
  }
}

@private
getTileValueUnchecked :: proc(tileMap : ^game.tile_map, 
                              world : ^game.world_map, xTile, yTile: i32) -> u32 {
  return tileMap.tiles[yTile * world.tileCountX + xTile]
}

@private
isTileMapPointEmpty :: proc(tileMap: ^game.tile_map, 
                            world : ^game.world_map, testX, testY: i32) -> (result: bool) {
  if tileMap != nil {

    if ( testX >= 0 && testX < world.tileCountX &&
         testY >= 0 && testY < world.tileCountY) 
    {
      tileMapValue := getTileValueUnchecked(tileMap, world, testX, testY)
      result = !bool(tileMapValue)
    }
  }
  return
}

@private
getTileMap :: proc(world: ^game.world_map, tileMapX, tileMapY: i32) -> (result: ^game.tile_map) {
  if ( tileMapX >= 0 && tileMapX < world.tileMapCountX && 
       tileMapY >= 0 && tileMapY < world.tileMapCountY) 
    {
      result = &world.tileMaps[tileMapY * world.tileMapCountX + tileMapX]
    }
  return 
}

@private
isWorldPointEmpty :: proc(world: ^game.world_map, rawPosition: game.raw_position) -> (result: bool) {

  conPosition := getCononicalPosition(world, rawPosition)
  tileMap := getTileMap(world, conPosition.tileMapX, conPosition.tileMapX)
  result = isTileMapPointEmpty(tileMap, world, conPosition.tileX, conPosition.tileY )
  return
}


@private
getCononicalPosition :: proc(world: ^game.world_map, pos: game.raw_position) -> (newPos: game.cononical_position) {

  newPos.tileMapY = pos.tileMapY
  newPos.tileMapX = pos.tileMapX

  x : f32 = (pos.pixelX - world.upperLeftX)
  y : f32 = (pos.pixelY - world.upperLeftY) 
  newPos.tileX = truncF32toI32( x / world.tileWidth);
  newPos.tileY = truncF32toI32( y / world.tileHeight);
  newPos.pixelX = x - (f32(newPos.tileX) * world.tileWidth);
  newPos.pixelY = y - (f32(newPos.tileY) * world.tileHeight);

  //TODO(Carbon) assert values are inside the correct ranges.

  if(newPos.tileX < 0) {
    newPos.tileX = world.tileCountX + newPos.tileX 
    newPos.tileMapX -= 1
  }
  if(newPos.tileX >= world.tileCountX) {
    newPos.tileX = newPos.tileX - world.tileCountX 
    newPos.tileMapX += 1
  }
  if(newPos.tileY < 0) {
    newPos.tileY = world.tileCountY + newPos.tileY 
    newPos.tileMapY -= 1
  }
  if(newPos.tileY >= world.tileCountY) {
    newPos.tileY = newPos.tileY - world.tileCountY  
    newPos.tileMapY += 1
  }

  return
}

@private
roundF32toI32 :: proc(num : f32) -> i32 {
  return i32(num + 0.5)
}
@private
truncF32toI32:: proc(num : f32) -> i32 {
  return i32(num)
}
@private
roundF32toU32 :: proc(num : f32) -> u32 {
  return u32(num + 0.5)
}

@private
drawRectangle :: proc (buffer: ^game.offscreen_buffer,
                       r, g, b: f32,
                       xMin_f, yMin_f, xMax_f, yMax_f: f32) {

  xMin := roundF32toI32(xMin_f)
  yMin := roundF32toI32(yMin_f)
  xMax := roundF32toI32(xMax_f)
  yMax := roundF32toI32(yMax_f)

  if xMin < 0 do xMin = 0
  if yMin < 0 do yMin = 0
  if xMax > buffer.width  do xMax = buffer.width
  if yMax > buffer.height do yMax = buffer.height

  color : u32 = roundF32toU32(0 * 255) << 24 |
                roundF32toU32(r * 255) << 16 |
                roundF32toU32(g * 255) << 8  |
                roundF32toU32(b * 255) << 0 
 

  bufferMemoryArray := buffer.memory[:]

  size : i32 = 10
  row : i32 = i32(yMin) * buffer.pitch 
  for y := yMin; y < yMax; y += 1 {
    for x := xMin; x < xMax; x += 1 {
      bufferMemoryArray[row + x] = color
    }
    row += buffer.pitch
  }
}

@private
renderFakePlayer :: proc  (bitmap: ^game.offscreen_buffer, 
                           position: [game.position]f32) {

  bitmapMemoryArray := bitmap.memory[:]
  size : i32 = 10
  row : i32 = i32(position[.y]) * bitmap.pitch 
  for y : i32 = i32(position[.y]); y < i32(position[.y]) + size; y += 1 {
    pixel := row + i32(position[.x])
    for x : i32 = i32(position[.x]); x < i32(position[.x]) + size; x += 1 {
      bitmapMemoryArray[pixel] = 0xFFFFFFFF 
      pixel += 1
    }
    row += bitmap.pitch
  }
}

@private
renderWeirdGradiant :: proc  (bitmap: ^game.offscreen_buffer,
                               greenOffset, blueOffset, redOffset: i32) {

  bitmapMemoryArray := bitmap.memory[:]
  size := bitmap.pitch * bitmap.height
  row : i32 = 0
  for y : i32 = 0; y < bitmap.height; y += 1 {
    pixel := row
    for x : i32 = 0; x < bitmap.width; x += 1 {
      red   : u8 = u8(redOffset)
      green : u8 = u8(x + greenOffset)
      blue  : u8 = u8(y + blueOffset)
      pad   : u8 = u8(0)

      bitmapMemoryArray[pixel] = (u32(pad) << 24) | (u32(red) << 16) |
                                  (u32(green) << 8) | (u32(blue) << 0)
      pixel += 1
    }
    row += bitmap.pitch
  }
}

