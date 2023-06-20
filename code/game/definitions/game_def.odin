package game

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
DEBUG_read_file_result :: struct {
  contentsSize: u32
  contents: rawptr
}

thread_context :: struct {
  placeholder :int
}


memory :: struct {
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

state :: struct {
  player     : [position]f32
  playerTile : [position]i32

}

input :: struct {
  controllers : [5]controller_input
  dtPerFrame  : f32
}

position :: enum {
  x,
  y
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

mouse_buttons :: enum {
  lmb,
  rmb,
  middle,
  x1,
  x2
}

controller_input :: struct {

  isConnected: bool,
  isAnalog:    bool,

  lStick:[position]f32 
  rStick:[position]f32 

  buttons:     [buttons]button_state

  //TODO(Carbon): Should I not have these hear but in input? 
  mouseButtons  : [mouse_buttons]button_state
  mouseZ, mouseX, mouseY : i32
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
  samples : [^]i16
  samplesPerSecond: u32
  sampleCount: int
}

world_map :: struct {

  tileMapCountX : i32
  tileMapCountY : i32

  tileCountX    : i32
  tileCountY    : i32

  upperLeftX : f32 
  upperLeftY : f32

  tileWidth  : f32
  tileHeight : f32

  tileMaps : [^]tile_map
}

tile_map :: struct {
  tiles      : [^]u32
}

empty_UpdateAndRender :: proc(thread: ^thread_context, gameMemory: ^memory, 
                              colorBuffer : ^offscreen_buffer, 
                              gameControls: ^input) { return } 

empty_GetSoundSamples :: proc( thread: ^thread_context, memory: ^memory, 
                               soundBuffer: ^sound_output_buffer) 
                               { return} 

