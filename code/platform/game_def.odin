package main

import DLIB       "core:dynlib"

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


game_memory :: struct {
  isInitialized        : bool
  permanentStorageSize : u64
  permanentStorage     : rawptr //NOTE(Carbon) required to be cleared to 0
  transientStorageSize : u64
  transientStorage     : rawptr //NOTE(Carbon) required to be cleared to 0

  debug_platformReadEntireFile: proc(filename: string) -> (
                                    DEBUG_read_file_result, bool)
  debug_platformWriteEntireFile: proc(filename: string, memorySize: u32,
                                      memory: rawptr) -> bool 

  debug_platformFreeFileMemory: proc(memory: rawptr)  
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

game_input :: struct {
  //TODO(Carbon): Add clock value
  controllers: [5]game_controller_input
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

game_controller_input :: struct {

  isConnected: bool,
  isAnalog:    bool,

  lStick:[game_position]f32 
  rStick:[game_position]f32 

  buttons:     [game_buttons]game_button_state
  
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

game_code :: struct {
  gameCodeDLL: DLIB.Library
  UpdateAndRender : proc(gameMemory:   ^game_memory, 
                         colorBuffer : ^game_offscreen_buffer, 
                         gameControls: ^game_input) 
  GetSoundSamples : proc( memory: ^game_memory, 
                          soundBuffer: ^game_sound_output_buffer) 
}


empty_UpdateAndRender :: proc(gameMemory:   ^game_memory, 
                        colorBuffer : ^game_offscreen_buffer, 
                        gameControls: ^game_input) { return } 

empty_GetSoundSamples :: proc( memory: ^game_memory, 
                               soundBuffer: ^game_sound_output_buffer) 
                               { return} 

