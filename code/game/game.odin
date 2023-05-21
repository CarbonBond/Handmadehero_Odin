package game

import MATH       "core:math"
import MEM        "core:mem"
import FMT        "core:fmt"

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

memory :: struct {
  isInitialized        : bool
  permanentStorageSize : u64
  permanentStorage     : rawptr //NOTE(Carbon) required to be cleared to 0
  transientStorageSize : u64
  transientStorage     : rawptr //NOTE(Carbon) required to be cleared to 0
}

game_state :: struct {
  playbackTime : f64 
  blueOffset   : i32 
  greenOffset  : i32
  redOffset    : i32
  toneHz       : u32
  toneVolume   : u16
  toneMulti    : u16
}

input :: struct {
  controllers: [4]controller_input
}

position :: enum {
  x,
  y
}

stick :: struct {
  start:  [position]f32,
  end:    [position]f32,
  max:    [position]f32,
  min:    [position]f32,
}

buttons :: enum {
  move_up,
  move_down,
  move_left,
  move_right,
  action_up,
  action_down,
  action_left,
  action_right,
  shoulder_left,
  shoulder_right,
  back,
  start,
}

controller_input :: struct {

  isConnected: bool,
  isAnalog:    bool,

  lStick: stick
  rStick: stick

  buttons:     [buttons]button_state
  
}

button_state :: struct {
  transitionCount: int
  endedDown:       bool
}

offscreen_buffer :: struct {
        memory        : [^]u32
        width         : i32
        height        : i32
        pitch         : i32
}

sound_output_buffer :: struct {
  samples : ^i16
  samplesPerSecond: u32
  sampleCount: u32
}

//Global for now


//TODO(Carbon) is there a better way?
lVibration : u16 = 0
rVibration : u16 = 0

// For Timing, controls input, bitmap buffer, and sound buffer.
// TODO: Controls, Bitmap, Sound Buffer
UpdateAndRender :: proc(gameMemory:   ^memory, 
                        colorBuffer : ^offscreen_buffer, 
                        soundBuffer:  ^sound_output_buffer,
                        gameControls: ^input) {
                        //TODO(Carbon): Pass Time

  when #config(SLOW, true) {
    assert(size_of(game_state) <= gameMemory.permanentStorageSize, "Game state to large for memory")
  }

  gameState := cast(^game_state)(gameMemory.permanentStorage)

  if !gameMemory.isInitialized {
    gameMemory.isInitialized = true

    gameState.playbackTime = 1
    gameState.toneHz      = 450
    gameState.toneVolume  = 500
    gameState.toneMulti   = 1
  }

  input0 := gameControls.controllers[0]
  if(input0.isAnalog) {

    gameState.greenOffset += i32(5 * (input0.rStick.end[.x]))
    gameState.blueOffset  += i32(5 * (input0.rStick.end[.y]))

    gameState.redOffset   += i32(1 * (input0.lStick.end[.x]))
    gameState.toneHz      =  -u32(500 * (input0.lStick.end[.y])) + 600

  } else {
  }

  if input0.buttons[.action_up].endedDown && gameState.toneVolume < 2000 { gameState.toneVolume += 10 }
  if input0.buttons[.action_down].endedDown && gameState.toneVolume > 0 { gameState.toneVolume -= 10 }
  if input0.buttons[.action_left].endedDown { gameState.toneMulti = 0 } else { gameState.toneMulti = 1 }

  if input0.buttons[.move_left].endedDown { lVibration = 60000}
  else { lVibration = 0 }

  if input0.buttons[.move_right].endedDown { rVibration = 60000 }
  else { rVibration = 0 }

  renderWeirdGradiant(colorBuffer, gameState.greenOffset, gameState.blueOffset, gameState.redOffset)

  //TODO(Carbon) Allow sample offsets
  outputSound(gameState, soundBuffer)
}

outputSound :: proc(gameState: ^game_state, soundBuffer: ^sound_output_buffer) {
  wavePeriod := soundBuffer.samplesPerSecond/gameState.toneHz
  buffer     := soundBuffer.samples 

  for frameIndex := 0; frameIndex < int(soundBuffer.sampleCount); frameIndex += 1 {
    amp := f64(gameState.toneVolume) * MATH.sin(gameState.playbackTime) * f64(gameState.toneMulti) 
    buffer^ = i16(amp)
    buffer = MEM.ptr_offset(buffer, 1)
    buffer^ = i16(amp)
    buffer = MEM.ptr_offset(buffer, 1)
    gameState.playbackTime += 6.28 / f64(wavePeriod)
  }
}

renderWeirdGradiant :: proc  (bitmap: ^offscreen_buffer,
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

