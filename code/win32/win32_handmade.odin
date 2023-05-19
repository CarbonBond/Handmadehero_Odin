package main

import FMT        "core:fmt"
import UTF16      "core:unicode/utf16"
import WIN32      "core:sys/windows"
import MATH       "core:math"
import MEM        "core:mem"
import INTRINSICS "core:intrinsics"

import XINPUT  "../xinput" 
import WASAPI  "../audio/wasapi"
import H       "../helper"

foreign import gdi32 "system:Gdi32.lib"
foreign gdi32 {
    CreateCompatibleDC :: proc "stdcall" (hdc : WIN32.HDC) -> WIN32.HDC ---
}

import GAME "../game" //Actual game

/*TODO(Carbon) Missing Functionality
  
  - Saved game locations
  - Getting a handle to out own executable
  - Asset loading 
  - Threading: Handle multiple threads
  - Raw input: Handle multiple keyboards)
  - Sleep/timeBegingPeriod: Avoid full cpu spin
  - ClipCursor(): Multiple monitors
  - Fullscreen
  - WM_SETCURSOR: Show cursor
  - QueryCanvelAutoplay
  - WM_ACTIVATEAPP: Not the active/focused app
  - Blit speed improvements
  - Hardware acceleration (OpenGL, Direct3D, Vulkin?)
  - GetKeyboardLayout: For international WASD

*/


// TODO(Carbon) Change from global
@private
running            : bool
globalBuffer       : w_offscreen_buffer
globalAudio        : w_audio
globalControls     : controls

S_OK :: WIN32.HRESULT(0)
DEFAULT_VOLUME  :: 1400
TONE_WAVELENGTH :: 440


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

w_offscreen_buffer :: struct {
        memory     : [^]u32
        width      : i32
        height     : i32
        pitch      : i32
        info       : WIN32.BITMAPINFO
}

controls :: struct {
  close : u32
}


main :: proc() {

  //Rebinding Controls test
    globalControls.close = WIN32.VK_ESCAPE
  //Controls Test end

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

      //NOTE(Carbon): TESTING WASAPI 

      audioSuccess := wInitAudio(&globalAudio)

      prevCounter : WIN32.LARGE_INTEGER
      WIN32.QueryPerformanceCounter(&prevCounter)
      
      perfCountFrequency : WIN32.LARGE_INTEGER
      WIN32.QueryPerformanceFrequency(&perfCountFrequency)

      prevCyclesCount : i64 = INTRINSICS.read_cycle_counter()

      redOffset, greenOffset, blueOffset: i32
       
      running = true 
      for running {

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

            // TODO(Carbon) Move to game code, not platform
            if buttonUp    do blueOffset  += 1
            if buttonDown  do blueOffset  -= 1
            if buttonLeft  do greenOffset += 1
            if buttonRight do greenOffset -= 1

            if buttonA     do redOffset   += 1
            if buttonY     do redOffset   -= 1

            if controller.gamepad.sThumbLX > XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE ||
              controller.gamepad.sThumbLX < -XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE {
              greenOffset += i32(controller.gamepad.sThumbLX / 10000 )
            }
            if controller.gamepad.sThumbLY > XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE ||
              controller.gamepad.sThumbLY < -XINPUT.GAMEPAD_LEFT_THUMB_DEADZONE {
              blueOffset -= i32(controller.gamepad.sThumbLY / 10000)
            }

            vibration : XINPUT.VIBRATION 

            if buttonB do vibration.wRightMotorSpeed = 60000
            if buttonX do vibration.wLeftMotorSpeed = 60000

            globalAudio.wavePeriod = f64(controller.gamepad.sThumbRY / 80 + 511)

            XINPUT.SetState(0, &vibration)

          } else {
            //NOTE (Carbon): Controller is not avaliable
          }
          
          break
        }

        
        colorBuffer : GAME.offscreen_buffer = {}
        colorBuffer.memory = globalBuffer.memory
        colorBuffer.width  = globalBuffer.width
        colorBuffer.height = globalBuffer.height
        colorBuffer.pitch  = globalBuffer.pitch

        GAME.UpdateAndRender(&colorBuffer, redOffset, greenOffset, blueOffset)

        wPlayAudio(&globalAudio) //NOTE(Carbon) not checking for success atm.

        windowWidth, windowHeight  := wWindowDemensions(window)
        wDisplayBufferInWindow(deviceContext, windowWidth, windowHeight, &globalBuffer)
        WIN32.ReleaseDC(window, deviceContext)


        endCyclesCount : i64 = INTRINSICS.read_cycle_counter()

        endCounter : WIN32.LARGE_INTEGER 
        WIN32.QueryPerformanceCounter(&endCounter)
        
        counterElapsed:= u64(endCounter - prevCounter) //NOTE Keep at end
        milliSecondsPerFrame := f64(counterElapsed * 1000) / f64(perfCountFrequency)
        FMT.print("FPS: ", 1000.0/f64(milliSecondsPerFrame), " | Miliseconds: ", milliSecondsPerFrame )

        cyclesElapsed := endCyclesCount - prevCyclesCount
        FMT.println(" | MegaCycles:", f64(cyclesElapsed) / (1000000))

        prevCounter = endCounter
        prevCyclesCount = endCyclesCount
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
          case globalControls.close:
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
                                                   WIN32.MEM_RESERVE|
                                                   WIN32.MEM_COMMIT,
                                                   WIN32.PAGE_READWRITE)

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
        /*NOTE(Carbon) Sense I'm not using DirectSound like HMH, how should I 
                       write to the "future".
                       I could make a seperate ring buffer + read/write ptr then
                       mem copy? Somethinig to think about.
        */
        amp := DEFAULT_VOLUME * MATH.sin(audio.playbackTime)
        buffer^ = i16(amp) // Left
        buffer = MEM.ptr_offset(buffer, 1)
        buffer^ = i16(amp) //Right
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
