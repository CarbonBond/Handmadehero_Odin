package game

import MATH       "core:math"
import MEM "core:mem"

playbackTime : f64 = 1
/*
*/

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


// For Timing, controls input, bitmap buffer, and sound buffer.
// TODO: Controls, Bitmap, Sound Buffer
UpdateAndRender :: proc(colorBuffer : ^offscreen_buffer, soundBuffer:^sound_output_buffer,
                        redOffset, greenOffset, blueOffset: i32, toneHz: u32) {

  /*
  blueOffset  : i32 = 0
  greenOffset : i32 = 0
  redOffset   : i32 = 0
  */

  renderWeirdGradiant(colorBuffer, greenOffset, blueOffset, redOffset)

  //TODO(Carbon) Allow sample offsets
  outputSound(soundBuffer, toneHz)
}

outputSound :: proc(soundBuffer: ^sound_output_buffer, toneHz: u32) {
  toneVolume : u16 = 2000
  wavePeriod := soundBuffer.samplesPerSecond/toneHz
  buffer     := soundBuffer.samples 

  for frameIndex := 0; frameIndex < int(soundBuffer.sampleCount); frameIndex += 1 {
    amp := f64(toneVolume) * MATH.sin(playbackTime)
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

