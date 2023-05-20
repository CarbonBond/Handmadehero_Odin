package game

import MATH       "core:math"
import MEM        "core:mem"
import FMT        "core:fmt"

playbackTime : f64 = 1

input :: struct {
  controllers: [4]controller_input
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

blueOffset  : i32 = 0
greenOffset : i32 = 0
redOffset   : i32 = 0
toneHz      : u32 = 450
toneVolume  : u16 = 1000
toneMulti   : u16 = 1

// For Timing, controls input, bitmap buffer, and sound buffer.
// TODO: Controls, Bitmap, Sound Buffer
UpdateAndRender :: proc(colorBuffer : ^offscreen_buffer, 
                        soundBuffer:  ^sound_output_buffer,
                        gameControls: ^input ) {

  input0 := gameControls.controllers[0]
  if(input0.isAnalog) {

    greenOffset += i32(5 * (input0.rStick.end[.x]))
    blueOffset  += i32(5 * (input0.rStick.end[.y]))

    redOffset   += i32(1 * (input0.lStick.end[.x]))
    toneHz      =  -u32(500 * (input0.lStick.end[.y])) + 600

  } else {
  }

  if input0.buttons[.action_up].endedDown && toneVolume < 2000 { toneVolume += 10 }
  if input0.buttons[.action_down].endedDown && toneVolume > 0 { toneVolume -= 10 }
  if input0.buttons[.action_left].endedDown { toneMulti = 0 } else { toneMulti = 1 }

  renderWeirdGradiant(colorBuffer, greenOffset, blueOffset, redOffset)

  //TODO(Carbon) Allow sample offsets
  outputSound(soundBuffer)
}

outputSound :: proc(soundBuffer: ^sound_output_buffer) {
  wavePeriod := soundBuffer.samplesPerSecond/toneHz
  buffer     := soundBuffer.samples 

  for frameIndex := 0; frameIndex < int(soundBuffer.sampleCount); frameIndex += 1 {
    amp := f64(toneVolume) * MATH.sin(playbackTime) * f64(toneMulti) 
    buffer^ = i16(amp)
    buffer = MEM.ptr_offset(buffer, 1)
    buffer^ = i16(amp)
    buffer = MEM.ptr_offset(buffer, 1)
    playbackTime += 6.28 / f64(wavePeriod)
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

