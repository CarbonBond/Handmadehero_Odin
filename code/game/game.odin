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
  tileMaps[0][0].xCount = 16
  tileMaps[0][0].yCount = 9
  tileMaps[0][0].tiles = cast([^]u32)&tiles00[0]
  tileMaps[0][0].upperLeftX = 0.0
  tileMaps[0][0].upperLeftY = 0.0
  tileMaps[0][0].tileWidth = f32(colorBuffer.width / i32(tileMaps[0][0].xCount))
  tileMaps[0][0].tileHeight = f32(colorBuffer.height / i32(tileMaps[0][0].yCount))

  tileMaps[0][1] = tileMaps[0][0]
  tileMaps[0][1].tiles = cast([^]u32)&tiles01[0]

  tileMaps[1][0] = tileMaps[0][0]
  tileMaps[1][0].tiles = cast([^]u32)&tiles10[0]

  tileMaps[1][1] = tileMaps[0][0]
  tileMaps[1][1].tiles = cast([^]u32)&tiles11[0]

  tileMap := &tileMaps[0][0]
  world : world_map
  world.tileMaps = cast([^]tile_map)&tileMaps[0][0]
  

  playerR, playerG, playerB : f32 = 0.0, 1.0, 0.0
  playerWidth  := 0.75 * tileMap.tileWidth
  playerHeight := tileMap.tileHeight
  playerLeft   := gameState.player[.x] - (0.5 * playerWidth)
  playerTop    := gameState.player[.y] - playerHeight

  if !gameMemory.isInitialized {
    gameMemory.isInitialized = true
    gameState.player[.x] = 100
    gameState.player[.y] = 300
  }

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

      if (isTileMapPointEmpty(tileMap, playerXNew - (0.5 * playerWidth), playerYNew) &&
          isTileMapPointEmpty(tileMap, playerXNew - (0.5 * playerWidth), playerYNew - (0.2 * playerHeight)) &&
          isTileMapPointEmpty(tileMap, playerXNew + (0.5 * playerWidth), playerYNew - (0.2 * playerHeight)) &&
          isTileMapPointEmpty(tileMap, playerXNew + (0.5 * playerWidth), playerYNew)) {
        
        gameState.player[.x] = playerXNew
        gameState.player[.y] = playerYNew
      }

    }
  }


  //clear screen
  drawRectangle(colorBuffer, 1.0, 0.0, 1.0,
                0, 0, f32(colorBuffer.width), f32(colorBuffer.height))


  for y : i32 = 0; y < tileMap.yCount; y += 1 { 
    for x : i32 = 0; x < tileMap.xCount; x += 1 {
      tile := getTileValueUnchecked(tileMap, x, y)
      distanceX := (f32(x) * tileMap.tileWidth) + tileMap.upperLeftX 
      distanceY := (f32(y) * tileMap.tileHeight) + tileMap.upperLeftY 
      drawRectangle(colorBuffer, f32(tile), f32(tile), f32(tile),
                    distanceX,   distanceY, 
                    distanceX + tileMap.tileWidth, distanceY + tileMap.tileHeight)
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
getTileValueUnchecked :: proc(tileMap : ^game.tile_map, xTile, yTile: i32) -> u32 {
  return tileMap.tiles[yTile * tileMap.xCount + xTile]
}

@private
isTileMapPointEmpty :: proc(tileMap: ^game.tile_map, x, y: f32) -> (result: bool) {
  tileX := truncF32toI32((x - tileMap.upperLeftX) / tileMap.tileWidth);
  tileY := truncF32toI32((y - tileMap.upperLeftY) / tileMap.tileHeight);

  if ( tileX >= 0 && tileX < i32(tileMap.xCount) &&
       tileY >= 0 && tileY < i32(tileMap.yCount)) 
  {
    tileMapValue := getTileValueUnchecked(tileMap, tileX, tileY)
    result = !bool(tileMapValue)
  }
  return
}

@private
getTileMap :: proc(worldMap: ^game.world_map, tileMapX, tileMapY: i32) -> (result: ^game.tile_map) {
  if ( tileMapX > 0 && tileMapX < worldMap.tileMapCountX && 
       tileMapY > 0 && tileMapY < worldMap.tileMapCountY) 
    {
      result = &worldMap.tileMaps[tileMapY * worldMap.tileMapCountX + tileMapY]
    }
  return 
}

@private
isWorldPointEmpty :: proc(worldMap: ^game.world_map, tileMapX, tileMapY: i32,
                          testX, testY: f32 ) -> (result: bool) {

  tileMap := getTileMap(worldMap, tileMapX, tileMapY)
  if (tileMap != nil) {
    tileX := truncF32toI32((testX - tileMap.upperLeftX) / tileMap.tileWidth);
    tileY := truncF32toI32((testY - tileMap.upperLeftY) / tileMap.tileHeight);

    if ( tileX >= 0 && tileX < i32(tileMap.xCount) &&
         tileY >= 0 && tileY < i32(tileMap.yCount)) 
    {
      tileMapValue := getTileValueUnchecked(tileMap, tileX, tileY)
      result = !bool(tileMapValue)
    }
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

