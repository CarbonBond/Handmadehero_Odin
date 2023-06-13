package main

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

//DEFINITION FOR DEBUG FUNCTIONS

DEBUG_read_file_result :: struct {
  contentsSize: u32
  contents: rawptr
}

thread_context :: struct {
  placeholder :int
}

game_memory :: struct {
  isInitialized        : bool
  permanentStorageSize : u64
  permanentStorage     : rawptr //NOTE(Carbon) required to be cleared to 0
  transientStorageSize : u64
  transientStorage     : rawptr //NOTE(Carbon) required to be cleared to 0

  debug_platformReadEntireFile: proc(thread: ^thread_context, filename: string) -> 
                                    ( DEBUG_read_file_result, bool)

  debug_platformWriteEntireFile: proc(thread: ^thread_context,filename: string,
                                      memorySize: u32, memory: rawptr) -> bool 

  debug_platformFreeFileMemory: proc(thread: ^thread_context,memory: rawptr)  
}

game_state :: struct {
  
}

game_input :: struct {
  controllers                : [5]game_controller_input
  secondsToAdvanceOverUpdate : f32
}

game_position :: enum {
  x,
  y
}

game_buttons :: enum {
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

mouse_buttons :: enum {
  lmb,
  rmb,
  middle,
  x1,
  x2
}

game_controller_input :: struct {

  isConnected: bool,
  isAnalog:    bool,

  lStick:[game_position]f32 
  rStick:[game_position]f32 

  buttons:     [game_buttons]game_button_state
  
  mouseButtons  : [mouse_buttons]game_button_state
  mouseZ, mouseX, mouseY : i32
}

game_button_state :: struct {
  transitionCount: int
  endedDown:       bool
}

game_offscreen_buffer :: struct {
        memory        : [^]u32
        width         : i32
        height        : i32
        pitch         : i32
}

game_sound_output_buffer :: struct {
  samples : [^]i16
  samplesPerSecond: u32
  sampleCount: int
}

//Global for now


//TODO(Carbon) is there a better way?

// For Timing, controls input, bitmap buffer, and sound buffer.
// TODO: Controls, Bitmap, Sound Buffer
@export
gameUpdateAndRender :: proc(thread: ^thread_context,
                            gameMemory:   ^game_memory, 
                            colorBuffer : ^game_offscreen_buffer, 
                            gameControls: ^game_input) {
                        //TODO(Carbon): Pass Time

  when #config(SLOW, true) {
    assert(size_of(game_state) <= gameMemory.permanentStorageSize, "Game state to large for memory")
  }

  gameState := cast(^game_state)(gameMemory.permanentStorage)

  if !gameMemory.isInitialized {
    gameMemory.isInitialized = true
  }


  for controller in gameControls.controllers {


    if !controller.isConnected do continue

    if(controller.isAnalog) {

    } else {

    }

  }


}

@export
gameGetSoundSamples :: proc(thread: ^thread_context,
                            memory: ^game_memory,
                            soundBuffer: ^game_sound_output_buffer) {
  gameState := cast(^game_state) memory.permanentStorage
  playbackTime := 1.0
  //NOTE(Carbon): Constants are Hz, Vol, multiplier (For mute)
  gameOutputSound(soundBuffer, 400, 1000, 0, &playbackTime )
}

@private
gameOutputSound :: proc(soundBuffer: ^game_sound_output_buffer, 
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
renderFakePlayer :: proc  (bitmap: ^game_offscreen_buffer, 
                           position: [game_position]f32) {

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
renderWeirdGradiant :: proc  (bitmap: ^game_offscreen_buffer,
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

