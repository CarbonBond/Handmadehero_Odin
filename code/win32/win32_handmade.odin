package main

import MATH       "core:math"
import FMT        "core:fmt"
import UTF16      "core:unicode/utf16"
import WIN32      "core:sys/windows"
import MEM        "core:mem"
import INTRINSICS "core:intrinsics"

import XINPUT  "../xinput" 
import WASAPI  "../audio/wasapi"
import HELPER       "../helper"

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

w_audio :: struct {
  client: ^WASAPI.IAudioClient2
  renderClient: ^WASAPI.IAudioRenderClient
  safetyBytes: int
  samplesPerSecond: u32
  bytesPerSample: int
  bufferSizeFrames: u32
}

w_offscreen_buffer :: struct {
  memory: [^]u32
  width : i32
  height: i32
  pitch : i32
  info  : WIN32.BITMAPINFO
}


//NOTE(Carbon) messing with rebindings
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

      samples := cast(^i16) WIN32.VirtualAlloc(
         nil,
         uint(globalAudio.bufferSizeFrames) * uint(globalAudio.bytesPerSample) * 2 ,
         WIN32.MEM_RESERVE | WIN32.MEM_COMMIT,
         WIN32.PAGE_READWRITE,
      )

      when #config(INTERNAL, true) {
        baseAddress : WIN32.LPVOID = MEM.ptr_offset(cast(^u64)cast(uintptr)(0),
                                                    HELPER.terabytes(2))
      } else {
        baseAddress : WIN32.LPVOID = nil
      }

      gameMemory : GAME.memory 
      gameMemory.permanentStorageSize = HELPER.megabytes(64);
      gameMemory.transientStorageSize = HELPER.gigabytes(4);

      totalSize := gameMemory.transientStorageSize + gameMemory.permanentStorageSize

      gameMemory.permanentStorage = WIN32.VirtualAlloc(
         baseAddress,
         uint(totalSize),
         WIN32.MEM_RESERVE | WIN32.MEM_COMMIT,
         WIN32.PAGE_READWRITE,
      )

      gameMemory.transientStorage = MEM.ptr_offset(cast(^u8)(gameMemory.permanentStorage),
                                                       gameMemory.permanentStorageSize)

      prevCounter : WIN32.LARGE_INTEGER
      WIN32.QueryPerformanceCounter(&prevCounter)
      
      perfCountFrequency : WIN32.LARGE_INTEGER
      WIN32.QueryPerformanceFrequency(&perfCountFrequency)

      prevCyclesCount : i64 = INTRINSICS.read_cycle_counter()

      inputs : [2]GAME.input
      newInput := &inputs[0]
      oldInput := &inputs[1]

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
        MaxControllerCount : u32 = XINPUT.XUSER_MAX_COUNT
        if MaxControllerCount > len(newInput.controllers) { 
          MaxControllerCount = len(newInput.controllers)
        }
        
        for i : WIN32.DWORD = 0; i < MaxControllerCount; i += 1 { 

          oldController : ^GAME.controller_input = &oldInput.controllers[i]
          newController : ^GAME.controller_input = &newInput.controllers[i]
          
          controller: XINPUT.STATE
          err := XINPUT.GetState(i, &controller)

          if err == WIN32.ERROR_SUCCESS {
            //NOTE (Carbon): Controller Plugged in
            pad := &controller.gamepad

            newController.isAnalog = true
            /* NOT USED
            //buttonStart     := bool(pad.wButtons & XINPUT.GAMEPAD_START)
            //buttonBack      := bool(pad.wButtons & XINPUT.GAMEPAD_BACK)

            buttonThumbL    := bool(pad.wButtons & XINPUT.GAMEPAD_LEFT_THUMB)
            buttonThumbR    := bool(pad.wButtons & XINPUT.GAMEPAD_RIGHT_THUMB)

            buttonShoulderL := bool(pad.wButtons & XINPUT.GAMEPAD_LEFT_SHOULDER)
            buttonShoulderR := bool(pad.wButtons & XINPUT.GAMEPAD_RIGHT_SHOULDER)
            */

            //The pressed buttons:
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.move_up],
                                        &newController.buttons[.move_up],
                                        XINPUT.GAMEPAD_DPAD_UP)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.move_down],
                                        &newController.buttons[.move_down],
                                        XINPUT.GAMEPAD_DPAD_DOWN)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.move_left],
                                        &newController.buttons[.move_left],
                                        XINPUT.GAMEPAD_DPAD_LEFT)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.move_right],
                                        &newController.buttons[.move_right],
                                        XINPUT.GAMEPAD_DPAD_RIGHT)

            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.action_up],
                                        &newController.buttons[.action_up],
                                        XINPUT.GAMEPAD_Y)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.action_down],
                                        &newController.buttons[.action_down],
                                        XINPUT.GAMEPAD_A)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.action_left],
                                        &newController.buttons[.action_left],
                                        XINPUT.GAMEPAD_X)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.action_right],
                                        &newController.buttons[.action_right],
                                        XINPUT.GAMEPAD_B)

            stickLeftX  : f32
            stickLeftY  : f32
            stickRightX : f32
            stickRightY : f32

            if(pad.sThumbLX < 0 ) { stickLeftX = f32(pad.sThumbLX) / 32768 }
            else { stickLeftX = f32(pad.sThumbLX) / 32767 }

            if(pad.sThumbLY < 0 ) { stickLeftY = f32(pad.sThumbLY) / -32768 }
            else { stickLeftY = f32(pad.sThumbLY) / -32767 }
            
            if(pad.sThumbRX < 0 ) { stickRightX = f32(pad.sThumbRX) / 32768 }
            else { stickRightX = f32(pad.sThumbRX) / 32767 }

            if(pad.sThumbRY < 0 ) { stickRightY = f32(pad.sThumbRY) / -32768 }
            else { stickRightY = f32(pad.sThumbRY) / -32767 }


            newController.lStick.start[.x] = oldController.lStick.end[.x] 
            newController.lStick.min[.x] = stickLeftX
            newController.lStick.max[.x] = stickLeftX
            newController.lStick.end[.x] = stickLeftX

            newController.lStick.start[.y] = oldController.lStick.end[.y] 
            newController.lStick.min[.y] = stickLeftY
            newController.lStick.max[.y] = stickLeftY
            newController.lStick.end[.y] = stickLeftY

            newController.rStick.start[.x] = oldController.rStick.end[.x] 
            newController.rStick.min[.x] = stickRightX
            newController.rStick.max[.x] = stickRightX
            newController.rStick.end[.x] = stickRightX
              
            newController.rStick.start[.y] = oldController.rStick.end[.y] 
            newController.rStick.min[.y] = stickRightY
            newController.rStick.max[.y] = stickRightY
            newController.rStick.end[.y] = stickRightY

            vibration : XINPUT.VIBRATION 
            vibration.wRightMotorSpeed = GAME.rVibration
            vibration.wLeftMotorSpeed = GAME.lVibration
            XINPUT.SetState(i, &vibration)

          } else {
            //NOTE (Carbon): Controller is not avaliable
          }
          
          break
        }

        
        colorBuffer : GAME.offscreen_buffer
        colorBuffer.memory = globalBuffer.memory
        colorBuffer.width  = globalBuffer.width
        colorBuffer.height = globalBuffer.height
        colorBuffer.pitch  = globalBuffer.pitch


        bufferPadding: u32
        globalAudio.client->GetCurrentPadding(&bufferPadding)
        //NOTE(Carbon): One frame is 2 channels at 16 bits, so total of 4 bytes

        nFramesToWrite := ((globalAudio.bufferSizeFrames / 72 ) - bufferPadding)

        soundBuffer : GAME.sound_output_buffer
        soundBuffer.samples = samples // Allocated before after init
        soundBuffer.samplesPerSecond = globalAudio.samplesPerSecond 
        soundBuffer.sampleCount = u32(nFramesToWrite)

        buffer: ^i16
        globalAudio.renderClient->GetBuffer(nFramesToWrite, cast(^^WIN32.BYTE)&buffer)
        if nFramesToWrite > 0 {
          MEM.copy(buffer, soundBuffer.samples, int(nFramesToWrite * 4))
        }

        globalAudio.renderClient->ReleaseBuffer(nFramesToWrite, 0)

        GAME.UpdateAndRender(&gameMemory, &colorBuffer, &soundBuffer, newInput)

        windowWidth, windowHeight  := wWindowDemensions(window)
        wDisplayBufferInWindow(deviceContext, windowWidth, windowHeight, &globalBuffer)
        WIN32.ReleaseDC(window, deviceContext)

        temp: ^GAME.input = newInput
        newInput = oldInput
        oldInput = temp

        endCyclesCount : i64 = INTRINSICS.read_cycle_counter()
        endCounter : WIN32.LARGE_INTEGER 
        WIN32.QueryPerformanceCounter(&endCounter)
        
        counterElapsed:= u64(endCounter - prevCounter) //NOTE Keep at end
        milliSecondsPerFrame := f64(counterElapsed * 1000) / f64(perfCountFrequency)
        cyclesElapsed := endCyclesCount - prevCyclesCount

        when #config(PRINT, true) { //TODO(Carbon): Better logging system
          FMT.println("FPS: ", 1000.0/f64(milliSecondsPerFrame), " | Miliseconds: ", milliSecondsPerFrame,
                      " | MegaCycles:", f64(cyclesElapsed) / (1000000))
                    }

        prevCounter = endCounter
        prevCyclesCount = endCyclesCount
      }
    } else {
      HELPER.MessageBox("Create Window Fail!", "Handmade Hero")
    //TODO(Carbon) Uses custom logging if CreateWindow failed
    }

  } else {
      HELPER.MessageBox("Register Class Fail!", "Handmade Hero")
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

      audio.samplesPerSecond = samplesPerSec 
      audio.bytesPerSample   = 16
      defaultPeriod: WASAPI.REFERENCE_TIME
      minPeriod: WASAPI.REFERENCE_TIME
      audio.client->GetDevicePeriod(&defaultPeriod, &minPeriod)

      hr = audio.client->GetBufferSize(&audio.bufferSizeFrames)
      hr = audio.client->Start()
      return true
}
   
@private 
wProcessXInputDigitalButton :: proc(XInputButtonState: WIN32.WORD,
                                   newState, oldState: ^GAME.button_state, 
                                   buttonBit: WIN32.WORD) {
  newState.endedDown = bool(XInputButtonState & buttonBit)
  oldState.transitionCount = 1 if (oldState.endedDown != newState.endedDown) else 0
}
