package main

import FMT     "core:fmt"
import UTF16   "core:unicode/utf16"
import WIN32   "core:sys/windows"
import MATH    "core:math"
import MEM     "core:mem"

import XINPUT  "xinput" 
import WASAPI  "audio/wasapi"
import H       "helper"

foreign import gdi32 "system:Gdi32.lib"
foreign gdi32 {
    CreateCompatibleDC :: proc "stdcall" (hdc : WIN32.HDC) -> WIN32.HDC ---
}


// TODO(Carbon) Change from global
@private
running            : bool
globalBuffer       : w_offscreen_buffer
globalAudio        : w_audio

S_OK :: WIN32.HRESULT(0)
TONE_WAVELENGTH :: 440


w_offscreen_buffer :: struct {
        memory        : [^]u32
        info          : WIN32.BITMAPINFO 
        width         : i32
        height        : i32
        pitch         : i32
}

w_audio :: struct {
  client: ^WASAPI.IAudioClient2
  renderClient: ^WASAPI.IAudioRenderClient
  playbackTime: f64 
  wavePeriod :  f64
  defaultPeriod: WASAPI.REFERENCE_TIME
  minPeriod: WASAPI.REFERENCE_TIME
  framesPerPeriod: int
  bufferSizeFrames: u32
}

main :: proc() {

  instance := cast(WIN32.HINSTANCE)WIN32.GetModuleHandleA(nil)

  wResizeDIBSection(&globalBuffer, 1280, 720)

  windowClass :               WIN32.WNDCLASSW
  windowClass.style         = WIN32.CS_HREDRAW | WIN32.CS_VREDRAW | WIN32.CS_OWNDC
  windowClass.lpfnWndProc   = wWindowCallback
  windowClass.hInstance     = instance
  /*TODO(Carbon) Set Icon
  windowClass.hIcon         = 
  */
  name :: "Handmade Hero"
  name_u16 : [len(name)+1]u16
  UTF16.encode_string(name_u16[:], name)
  windowClass.lpszClassName = &name_u16[0]

  if WIN32.RegisterClassW(&windowClass) != 0 {
    window: WIN32.HWND = WIN32.CreateWindowExW(
      0,
      windowClass.lpszClassName,
      &name_u16[0],
      WIN32.WS_OVERLAPPEDWINDOW|WIN32.WS_VISIBLE,
      WIN32.CW_USEDEFAULT,
      WIN32.CW_USEDEFAULT,
      WIN32.CW_USEDEFAULT,
      WIN32.CW_USEDEFAULT,
      nil,
      nil,
      instance,
      nil,
      )
    if window != nil  {
      //NOTE(Carbon) As we use CS_OWNDC we don't share the context 
      //             We can use one DC
      deviceContext := WIN32.GetDC(window)

      blueOffset  : i32 = 0
      greenOffset : i32 = 0
      redOffset   : i32 = 0

      //NOTE(Carbon): TESTING WASAPI 

      audioSuccess := wInitAudio(&globalAudio)
      
      running = true 
      for running {

        if audioSuccess do wPlayAudio(&globalAudio) 

        message: WIN32.MSG
        for WIN32.PeekMessageW(&message, nil, 0, 0, WIN32.PM_REMOVE) {

          if message.message == WIN32.WM_QUIT {
            running = false;
          }

          WIN32.TranslateMessage(&message)
          WIN32.DispatchMessageW(&message)
        }

        //TODO(Carbon) Add controller polling here
        //TODO(Carbon) Whats the best polling frequency? 
        for i : WIN32.DWORD = 0; i < XINPUT.XUSER_MAX_COUNT; i += 1 { 

          controller: XINPUT.STATE
          err := XINPUT.GetState(i, &controller)

          if err == WIN32.ERROR_SUCCESS {
            //NOTE (Carbon): Controller Plugged in

            //The pressed buttons:
            buttonUp        := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_DPAD_UP)
            buttonDown      := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_DPAD_DOWN)
            buttonLeft      := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_DPAD_LEFT)
            buttonRight     := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_DPAD_RIGHT)
            buttonStart     := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_START)
            buttonBack      := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_BACK)
            buttonThumbL    := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_LEFT_THUMB)
            buttonThumbR    := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_RIGHT_THUMB)
            buttonShoulderL := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_LEFT_SHOULDER)
            buttonShoulderR := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_RIGHT_SHOULDER)
            buttonA         := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_A)
            buttonB         := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_B)
            buttonX         := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_X)
            buttonY         := bool(controller.gamepad.wButtons & XINPUT.GAMEPAD_Y)

            if buttonUp    do blueOffset  += 1
            if buttonDown  do blueOffset  -= 1
            if buttonLeft  do greenOffset += 1
            if buttonRight do greenOffset -= 1

            if buttonA     do redOffset   += 1
            if buttonY     do redOffset   -= 1

            vibration : XINPUT.VIBRATION 

            if buttonB do vibration.wRightMotorSpeed = 60000
            if buttonX do vibration.wLeftMotorSpeed = 60000

            if controller.gamepad.sThumbLX > XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE ||
              controller.gamepad.sThumbLX < -XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE {
              greenOffset += i32(controller.gamepad.sThumbLX >> 12 )
            }
            if controller.gamepad.sThumbLY > XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE ||
              controller.gamepad.sThumbLY < -XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE {
              blueOffset -= i32(controller.gamepad.sThumbLY >> 12)
            }

            globalAudio.wavePeriod = f64(controller.gamepad.sThumbRY>>10 * 15 + 511)
            FMT.println(globalAudio.wavePeriod)

            XINPUT.SetState(0, &vibration)

          } else {
            //NOTE (Carbon): Controller is not avaliable
          }
          
          break
        }

        wRenderWeirdGradiant(&globalBuffer, greenOffset, blueOffset, redOffset)

        windowWidth, windowHeight  := wWindowDemensions(window)
        wDisplayBufferInWindow(deviceContext, windowWidth, windowHeight, &globalBuffer)
        WIN32.ReleaseDC(window, deviceContext)

      }
    } else {
      H.MessageBox("Create Window Fail!", "Handmade Hero")
    //TODO(Carbon) Uses custom logging if CreateWindow failed
    }

  } else {
      H.MessageBox("Register Class Fail!", "Handmade Hero")
  //TODO(Carbon) Uses custom logging if RegisterClass failed
  }
}

wWindowCallback :: proc "stdcall" (window: WIN32.HWND  , message: WIN32.UINT,
                                   wParam: WIN32.WPARAM, lParam : WIN32.LPARAM) -> 
                                  WIN32.LRESULT {
  result : WIN32.LRESULT = 0
  switch(message) {

    case WIN32.WM_DESTROY:
      running = false
      //TODO(Carbon) Handle as an error?

    case WIN32.WM_CLOSE:
      running = false
      //TODO(Carbon) Possibly message/warn user.

    case WIN32.WM_ACTIVATEAPP:

    case WIN32.WM_PAINT:
      paint : WIN32.PAINTSTRUCT
      deviceContext := WIN32.BeginPaint(window, &paint)
      x      :=  paint.rcPaint.left
      y      :=  paint.rcPaint.top
      height :=  paint.rcPaint.bottom - paint.rcPaint.top
      width  :=  paint.rcPaint.right  - paint.rcPaint.left

      windowWidth, windowHeight := wWindowDemensions(window)  
      wDisplayBufferInWindow(deviceContext, windowWidth, windowHeight, &globalBuffer)
      WIN32.EndPaint(window, &paint)

    case WIN32.WM_SYSKEYDOWN: fallthrough
    case WIN32.WM_SYSKEYUP: fallthrough
    case WIN32.WM_KEYDOWN: fallthrough
    case WIN32.WM_KEYUP:
      
      VKCode  := u32(wParam)
      wasDown := bool(lParam & ( 1 << 30))
      isDown  := bool(lParam & ( 1 << 31) == 0)
      altDown := bool(lParam & ( 1 << 29))

      //Stop Key Repeating
      if wasDown != isDown {
        switch VKCode {
          case 'W': 
          case 'A': 
          case 'S': 
          case 'D': 
          case 'Q': 
          case 'E': 

          case WIN32.VK_UP:
          case WIN32.VK_LEFT:
          case WIN32.VK_DOWN:
          case WIN32.VK_RIGHT:
          case WIN32.VK_ESCAPE:
            running = false
          case WIN32.VK_SPACE:
          case WIN32.VK_F4:
            if altDown do running = false
          
        }
      }
      
    case: //Default
      result = WIN32.DefWindowProcW(window, message, wParam, lParam)
  }

  return result
}

wResizeDIBSection :: proc (bitmap: ^w_offscreen_buffer, 
                                         width, height: i32) {

  if bitmap.memory != nil {
    WIN32.VirtualFree(bitmap.memory, 0, WIN32.MEM_RELEASE)
  }

  bitmap.height = height
  bitmap.width  = width
  bitmap.pitch   = bitmap.width

  bitmap.info.bmiHeader.biSize = size_of(bitmap.info.bmiHeader)
  bitmap.info.bmiHeader.biWidth          = bitmap.width
  bitmap.info.bmiHeader.biHeight         = -bitmap.height
  bitmap.info.bmiHeader.biPlanes         = 1
  bitmap.info.bmiHeader.biBitCount       = 32
  bitmap.info.bmiHeader.biCompression    = WIN32.BI_RGB

  bytesPerPixel  : i32 = 4 
  bitmapSize     := uint(bytesPerPixel * bitmap.width * bitmap.height)
  bitmap.memory   = cast([^]u32)WIN32.VirtualAlloc(nil, bitmapSize, 
                                                   WIN32.MEM_COMMIT,
                                                   WIN32.PAGE_READWRITE)


  wRenderWeirdGradiant(bitmap, 0, 0, 0)

}

wDisplayBufferInWindow :: proc "std" (deviceContext: WIN32.HDC, 
                                     windowWidth, windowHeight: i32,
                                     bitmap: ^w_offscreen_buffer) {


  //TODO(Carbon) Aspect ration correction.
  //TODO(Carbon) Play with stretch modes.
  WIN32.StretchDIBits(
    deviceContext,
    /*
    x, y, width, height,
    x, y, width, height,
    */
    0, 0, windowWidth, windowHeight,
    0, 0, bitmap.width, bitmap.height,
    bitmap.memory,
    &bitmap.info,
    WIN32.DIB_RGB_COLORS,
    WIN32.SRCCOPY
  )

}

wRenderWeirdGradiant :: proc  (bitmap: ^w_offscreen_buffer,
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

wWindowDemensions :: proc "std" (window : WIN32.HWND) -> (width, height: i32) {
        clientRect: WIN32.RECT 
        WIN32.GetClientRect(window, &clientRect)
        width  = clientRect.right - clientRect.left
        height = clientRect.bottom - clientRect.top
        return
}


wInitAudio :: proc(audio: ^w_audio, samplesPerSec: u32 = 41000) -> bool {

      hr := WIN32.CoInitializeEx(nil, WIN32.COINIT.SPEED_OVER_MEMORY)

      deviceEnumerator : ^WASAPI.IMMDeviceEnumerator
      hr = WIN32.CoCreateInstance(
        &WASAPI.CLSID_MMDeviceEnumerator,
        nil,
        WASAPI.CLSCTX_ALL,
        WASAPI.IMMDeviceEnumerator_UUID,
        cast(^rawptr)&deviceEnumerator,
      )

      if hr != S_OK { return false }

      audioDevice: ^WASAPI.IMMDevice
      hr = deviceEnumerator->GetDefaultAudioEndpoint(WASAPI.EDataFlow.eRender,
                                                      WASAPI.ERole.eConsole,
                                                      &audioDevice)
      if hr != S_OK { return false }

      deviceEnumerator->Release()
      hr = audioDevice->Activate(WASAPI.IAudioClient2_UUID,
                                  WASAPI.CLSCTX_ALL, nil
                                  cast(^rawptr)&audio.client)
      
      if hr != S_OK { return false }

      audioDevice->Release()

      mix_format: WASAPI.WAVEFORMATEX = {
        wFormatTag      = 1, // WAVE_FORMAT_PCM, as we only need two channel
        nChannels       = 2,  
        nSamplesPerSec  = samplesPerSec,
        wBitsPerSample  = 16,
        nBlockAlign     = 2 * 16 / 8, // nChannel * wBitsPerSample / 8 bits
        nAvgBytesPerSec = samplesPerSec * 2 * 16 / 8, //nSamplesPerSec * nBlockAlign
      }

      init_stream_flags : u32 = WASAPI.AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                          WASAPI.AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY|
                          WASAPI.AUDCLNT_STREAMFLAGS_RATEADJUST

      REFTIMES_PER_SEC :: 8 * 1_000_000 // Milliseconds
      requested_buffer_duration: i64 = REFTIMES_PER_SEC
      hr = audio.client->Initialize(WASAPI.AUDCLNT_SHAREMODE.SHARED,
                                    init_stream_flags,
                                    requested_buffer_duration
                                    0,
                                    &mix_format,
                                    nil)


      hr = audio.client->GetService(WASAPI.IAudioRenderClient_UUID,
                                   cast(^rawptr)&audio.renderClient)

      audio.playbackTime = 1
      audio.wavePeriod = f64(samplesPerSec / TONE_WAVELENGTH)
      audio.client->GetDevicePeriod(&audio.defaultPeriod, &audio.minPeriod)
      audio.framesPerPeriod = int(44100 * 
                              (f64(audio.defaultPeriod) / (10000.0 * 1000.0)) + 0.5) 

      hr = audio.client->GetBufferSize(&audio.bufferSizeFrames)
      hr = audio.client->Start()


      return true
}

wPlayAudio :: proc (audio: ^w_audio) {
   
  bufferPadding: u32
  hr := audio.client->GetCurrentPadding(&bufferPadding)

  if hr == S_OK {

    latency := audio.bufferSizeFrames / 72
    nFramesToWrite := latency - bufferPadding
    if nFramesToWrite <= 0 do return

    buffer: ^i16
    hr = audio.renderClient->GetBuffer(nFramesToWrite, cast(^^WIN32.BYTE)&buffer)

    if (hr == S_OK) {

      for frameIndex := 0; frameIndex < int(nFramesToWrite); frameIndex += 1 {
      amp := 300 * MATH.sin(audio.playbackTime)
      buffer^ = i16(amp)
      buffer = MEM.ptr_offset(buffer, 1)
      buffer^ = i16(amp)
      buffer = MEM.ptr_offset(buffer, 1)
      audio.playbackTime += 6.28 / audio.wavePeriod
      if audio.playbackTime > 6.28 do audio.playbackTime -= 6.28
      }
      hr = audio.renderClient->ReleaseBuffer(nFramesToWrite, 0)
      if hr != S_OK {
        //TODO(Carbon): Diagnostic for ReleaseBuffer
      }
    } else {
      //TODO(Carbon): Diagnostic for GetBuffer
    }

  } else {
    //TODO(Carbon): Diagnostic for GetCurrentPadding
  }
}
