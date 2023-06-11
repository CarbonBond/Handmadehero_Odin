package main

import DLIB       "core:dynlib"

/*TODO(Brandon)
Figure out a better way to handle definitions of 
types so I don't have to edit this file and 
the game file.
*/

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
                                    (DEBUG_read_file_result, bool)

  debug_platformWriteEntireFile: proc(thread: ^thread_context, filename: string,
                                      memorySize: u32, memory: rawptr) -> bool 

  debug_platformFreeFileMemory: proc(thread: ^thread_context, memory: rawptr)  
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

  //TODO(Carbon): Should I not have these hear but in game_input? 
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

empty_UpdateAndRender :: proc(thread: ^thread_context, gameMemory: ^game_memory, 
                              colorBuffer : ^game_offscreen_buffer, 
                              gameControls: ^game_input) { return } 

empty_GetSoundSamples :: proc( thread: ^thread_context, memory: ^game_memory, 
                               soundBuffer: ^game_sound_output_buffer) 
                               { return} 

