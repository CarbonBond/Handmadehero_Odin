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

  tileMap := [][]i32{
    {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
  }

  upperLeftX : f32 = 0.0
  upperLeftY : f32 = 0.0
  tileWidth := f32(colorBuffer.width / i32(len(tileMap[0])))
  tileHeight := f32(colorBuffer.height / i32(len(tileMap)))


  if !gameMemory.isInitialized {
    gameMemory.isInitialized = true
    gameState.player[.x] = 400
    gameState.player[.y] = 400
  }

  for controller in gameControls.controllers {

    if !controller.isConnected do continue

    if(controller.isAnalog) {
      if controller.buttons[.action_down].endedDown {
        gameState.player[.x] = 400
        gameState.player[.y] = 400
      }
    } else {

      playerDX, playerDY : f32 = 0.0, 0.0

      if controller.buttons[.move_up].endedDown    do playerDY = -200.0
      if controller.buttons[.move_down].endedDown  do playerDY = 200.0
      if controller.buttons[.move_left].endedDown  do playerDX = -200.0
      if controller.buttons[.move_right].endedDown do playerDX = 200.0

      playerXNew := gameState.player[.x] + (playerDX * gameControls.dtPerFrame)
      playerYNew := gameState.player[.y] + (playerDY * gameControls.dtPerFrame)

      playerTileX := truncF32toI32((gameState.player[.x] - upperLeftX) / tileWidth);
      playerTileY := truncF32toI32((gameState.player[.y] - upperLeftY) / tileHeight);

      isMoveValid := false
      if ( playerTileX >= 0 && playerTileX < i32(len(tileMap[0])) &&
           playerTileY >= 0 && playerTileY < i32(len(tileMap))
         ) {
           tileMapValue := tileMap[playerTileY][playerTileX]
           isMoveValid = !bool(tileMapValue)
         }

      if isMoveValid {
        gameState.player[.x] = playerXNew
        gameState.player[.y] = playerYNew
      }

    }
  }


  //clear screen
  drawRectangle(colorBuffer, 1.0, 0.0, 1.0,
                0, 0, f32(colorBuffer.width), f32(colorBuffer.height))


  for row, y in tileMap {
    for cell, x in row {
      distanceX := (f32(x) * tileWidth) + upperLeftX
      distanceY := (f32(y) * tileWidth) + upperLeftY
      drawRectangle(colorBuffer, f32(cell), f32(cell), f32(cell),
                    distanceX,   distanceY, 
                    distanceX + tileWidth, distanceY + tileHeight)
    }
  }

  playerR, playerG, playerB : f32 = 0.0, 1.0, 0.0
  playerWidth  := 0.75 * tileWidth
  playerHeight := tileHeight
  playerLeft   := gameState.player[.x] - (0.5 * playerWidth)
  playerTop    := gameState.player[.y] - playerHeight
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

