package main

import MATH       "core:math"
import FMT        "core:fmt"
import UTF16      "core:unicode/utf16"
import DLIB       "core:dynlib"
import OS         "core:os"

import WIN32      "core:sys/windows"
import MEM        "core:mem"
import INTRINSICS "core:intrinsics"

foreign import "system:kernel32.lib"
foreign kernel32 {
	ExitProcess :: proc "stdcall" (exit_code:  u32) ---
}

import XINPUT  "../windows_port/xinput" 
import WASAPI  "../windows_port/audio/wasapi"
import WINGDI  "../windows_port/wingdi/"
import HELPER  "../helper"


/*TODO(Carbon) Missing Functionality
  
  - Saved game locations
  - Getting a handle to out own executable
  - Asset loading 
  - Threading: Handle multiple threads
  - Raw input: Handle multiple keyboards)
  - ClipCursor(): Multiple monitors
  - Fullscreen
  - WM_SETCURSOR: Show cursor
  - QueryCanvelAutoplay
  - WM_ACTIVATEAPP: Not the active/focused app
  - Blit speed improvements
  - Hardware acceleration (OpenGL, Direct3D, Vulkin?)
  - GetKeyboardLayout: For international WASD

*/

//TESTING 
playbackTime := 1.0
//END TESTING


// TODO(Carbon) Combined platform_state and recording_state
@private
platform_state :: struct {
  running      : bool
  pause        : bool
  buffer       : w_offscreen_buffer
  audio        : w_audio
  controls     : controls
  perfCountFrequency : WIN32.LARGE_INTEGER
  filepath     : string
}

recording_state :: struct {
  gameMemoryBlock     : rawptr
  totalBlockSize      : u64

  recordingHandle     : WIN32.HANDLE
  inputRecordingIndex : int

  playbackHandle      : WIN32.HANDLE
  inputPlayingIndex   : int

  fileLocation        : string
}

S_OK :: WIN32.HRESULT(0)

w_audio :: struct {
  client: ^WASAPI.IAudioClient2
  renderClient: ^WASAPI.IAudioRenderClient
  safetyBytes: int
  samplesPerSecond: u32
  bytesPerSample: u16
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

globalState : platform_state

main :: proc() {
  using WIN32

  //Rebinding Controls test
    globalState.controls.close = VK_ESCAPE
  //Controls Test end

  instance := cast(HINSTANCE)GetModuleHandleW(nil)
  fileName_w : [255]u16
  GetModuleFileNameW(nil, cast(^u16)&fileName_w[0], len(fileName_w))

  filePath_a : [255]u8
  WideCharToMultiByte(CP_UTF8, 0, cast(^u16)&fileName_w[0]
                      len(fileName_w), cast(^u8)&filePath_a[0], len(filePath_a), nil, nil)

  onePastLastSlash := 0
  for item, index in filePath_a {
    if item == '\\' {
      onePastLastSlash = index + 1
    }
  }
  for i := onePastLastSlash; i < len(filePath_a); i += 1 {
    filePath_a[i] = 0
  }

  globalState.filepath = string(filePath_a[:])

  dllFile := "game.dll"
  dllFileFullPath := catString( globalState.filepath, dllFile)

  dllTempFile := "game_temp.dll"
  dllTempFileFullPath := catString(globalState.filepath, dllTempFile)

  wResizeDIBSection(&globalState.buffer, 1280, 720)

  windowClass :               WNDCLASSW
  windowClass.style         = CS_HREDRAW | CS_VREDRAW 
  windowClass.lpfnWndProc   = wWindowCallback
  windowClass.hInstance     = instance
  /*TODO(Carbon) Set Icon
  windowClass.hIcon         = 
  */
  name :: "Handmade Hero"
  name_u16 : [len(name)+1]u16
  UTF16.encode_string(name_u16[:], name)
  windowClass.lpszClassName = &name_u16[0]

  monitorRefreshHz := 120
  gameUpdateHz := f32(monitorRefreshHz) / 2
  targetSecondsPerFrame : f32 = 1 / f32(gameUpdateHz)

  desiredSchedulerMS : u32 = 1
  sleepIsGranular := (timeBeginPeriod(desiredSchedulerMS) == TIMERR_NOERROR )
   
  QueryPerformanceFrequency(&globalState.perfCountFrequency)

  if RegisterClassW(&windowClass) != 0 {
    window: HWND = CreateWindowExW(
      WS_EX_LAYERED,
      windowClass.lpszClassName,
      &name_u16[0],
      WS_OVERLAPPEDWINDOW|WS_VISIBLE,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      nil,
      nil,
      instance,
      nil,
      )

    if window != nil  {

      refreshDC := GetDC(window)
      wRefreshHz := WINGDI.GetDeviceCaps(refreshDC, WINGDI.VREFRESH)
      ReleaseDC(window, refreshDC)
      if wRefreshHz > 1 {
        monitorRefreshHz = wRefreshHz
      }
      //NOTE(Carbon): TESTING WASAPI 
      audioSuccess := wInitAudio(&globalState.audio)

      samples := cast(^i16) VirtualAlloc(
         nil,
         uint(globalState.audio.bufferSizeFrames) * uint(globalState.audio.bytesPerSample) * 2 ,
         MEM_RESERVE | MEM_COMMIT,
         PAGE_READWRITE,
      )

      when #config(INTERNAL, true) {
        baseAddress : LPVOID = MEM.ptr_offset(cast(^u64)cast(uintptr)(0),
                                                    HELPER.terabytes(2))
      } else {
        baseAddress : LPVOID = nil
      }

      recordingState : recording_state
      recordingFile := "temp\\input_recording.igmr"
      recordingFileFullPath := catString( globalState.filepath, recordingFile)
      recordingState.fileLocation = recordingFileFullPath


      gameMemory : game_memory 
      gameMemory.permanentStorageSize = HELPER.megabytes(64);
      gameMemory.transientStorageSize = HELPER.megabytes(501);
      gameMemory.debug_platformReadEntireFile =  DEBUG_platformReadEntireFile
      gameMemory.debug_platformWriteEntireFile = DEBUG_platformWriteEntireFile
      gameMemory.debug_platformFreeFileMemory =  DEBUG_platformFreeFileMemory

      totalSize := gameMemory.transientStorageSize + gameMemory.permanentStorageSize
      recordingState.totalBlockSize = totalSize
      //TODO(Carbon): Use MEM_LARGE_PADGE and call adjust toekn privileges
      recordingState.gameMemoryBlock = VirtualAlloc( baseAddress,
                                                     uint(totalSize),
                                                     MEM_RESERVE | MEM_COMMIT,
                                                     PAGE_READWRITE)

      gameMemory.permanentStorage = recordingState.gameMemoryBlock
      gameMemory.transientStorage = MEM.ptr_offset(cast(^u8)(gameMemory.permanentStorage),
                                                       gameMemory.permanentStorageSize)

      prevCounter := wGetWallClock()
      prevCyclesCount : i64 = INTRINSICS.read_cycle_counter()

      inputs : [2]game_input
      newInput := &inputs[0]
      oldInput := &inputs[1]

      game := wLoadGameCode(dllFileFullPath, dllTempFileFullPath)

      globalState.running = true 
      for globalState.running {
        lastWriteTime, er := OS.last_write_time_by_name(dllFileFullPath)
        if game.lastWriteTime != lastWriteTime {
          wUnloadGameCode(&game)
          game = wLoadGameCode(dllFileFullPath, dllTempFileFullPath)
        }

        oldKeyboardController : ^game_controller_input = &oldInput.controllers[0]
        newKeyboardController : ^game_controller_input = &newInput.controllers[0]
        newKeyboardController^ = game_controller_input{}

        newKeyboardController.isConnected = true
        for i in game_buttons {
          newKeyboardController.buttons[i].endedDown = oldKeyboardController.buttons[i].endedDown
        }

        //TODO(Carbon) Add controller polling here
        //TODO(Carbon) Whats the best polling frequency? 
        MaxControllerCount : u32 = XINPUT.XUSER_MAX_COUNT
        if MaxControllerCount >= len(newInput.controllers) { 
          MaxControllerCount = len(newInput.controllers) - 1
        }

        wHandlePendingMessages(&recordingState, newKeyboardController)
        
        for i : DWORD = 0; i < MaxControllerCount; i += 1 { 

          ourController := i + 1
          oldController : ^game_controller_input = &oldInput.controllers[ourController]
          newController : ^game_controller_input = &newInput.controllers[ourController]
          
          controller: XINPUT.STATE
          err := XINPUT.GetState(i, &controller)

          if err == ERROR_SUCCESS {
            //NOTE (Carbon): Controller Plugged in
            pad := &controller.gamepad

            newController.isConnected = true
            newController.isAnalog = oldController.isAnalog

            if newController.lStick[.x] != 0 || newController.lStick[.y] != 0 ||
               newController.rStick[.x] != 0 || newController.rStick[.y] != 0 {
            newController.isAnalog = true
            }
            
            /* NOT USED
            //buttonStart     := bool(pad.wButtons & XINPUT.GAMEPAD_START)
            //buttonBack      := bool(pad.wButtons & XINPUT.GAMEPAD_BACK)

            buttonThumbL    := bool(pad.wButtons & XINPUT.GAMEPAD_LEFT_THUMB)
            buttonThumbR    := bool(pad.wButtons & XINPUT.GAMEPAD_RIGHT_THUMB)

            buttonShoulderL := bool(pad.wButtons & XINPUT.GAMEPAD_LEFT_SHOULDER)
            buttonShoulderR := bool(pad.wButtons & XINPUT.GAMEPAD_RIGHT_SHOULDER)
            */

            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.shoulder_left],
                                        &newController.buttons[.shoulder_left],
                                        XINPUT.GAMEPAD_LEFT_SHOULDER)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.shoulder_right],
                                        &newController.buttons[.shoulder_right],
                                        XINPUT.GAMEPAD_RIGHT_SHOULDER)

            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.start],
                                        &newController.buttons[.start],
                                        XINPUT.GAMEPAD_START)
            wProcessXInputDigitalButton(pad.wButtons,
                                        &oldController.buttons[.back],
                                        &newController.buttons[.back],
                                        XINPUT.GAMEPAD_BACK)

            //The pressed buttons:

            if bool(pad.wButtons & XINPUT.GAMEPAD_BACK ) {
              globalState.running = false
            }

            //Dpad overwriting thumbsticks incase of use
            if bool(pad.wButtons & XINPUT.GAMEPAD_DPAD_UP) {
              newController.lStick[.y] = 1
            }
            if bool(pad.wButtons & XINPUT.GAMEPAD_DPAD_DOWN) {
              newController.lStick[.y] = -1
            }
            if bool(pad.wButtons & XINPUT.GAMEPAD_DPAD_LEFT) {
              newController.lStick[.x] = -1
            }
            if bool(pad.wButtons & XINPUT.GAMEPAD_DPAD_RIGHT) {
              newController.lStick[.x] = 1
            }

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

            // Thumbsticks
            threshhold : f32 = 0.5
            wProcessXInputDigitalButton(u16(newController.lStick[.y] > threshhold),
                                        &oldController.buttons[.move_up],
                                        &newController.buttons[.move_up],
                                        1)
            wProcessXInputDigitalButton(u16(newController.lStick[.y] < -threshhold),
                                        &oldController.buttons[.move_down],
                                        &newController.buttons[.move_down],
                                        1)
            wProcessXInputDigitalButton(u16(newController.lStick[.x] < -threshhold),
                                        &oldController.buttons[.move_left],
                                        &newController.buttons[.move_left],
                                        1)
            wProcessXInputDigitalButton(u16(newController.lStick[.x] > threshhold),
                                        &oldController.buttons[.move_right],
                                        &newController.buttons[.move_right],
                                        1)
              
            /* R stick not used
            wProcessXInputDigitalButton(u16(newController.rStick[.y] < -threshhold),
                                        &oldController.buttons[.action_up],
                                        &newController.buttons[.move_up],
                                        1)
            wProcessXInputDigitalButton(u16(newController.rStick[.y] > threshhold),
                                        &oldController.buttons[.action_down],
                                        &newController.buttons[.action_down],
                                        1)
            wProcessXInputDigitalButton(u16(newController.rStick[.x] > threshhold),
                                        &oldController.buttons[.action_left],
                                        &newController.buttons[.action_left],
                                        1)
            wProcessXInputDigitalButton(u16(newController.rStick[.x] < -threshhold),
                                        &oldController.buttons[.action_right],
                                        &newController.buttons[.actrion_right],
                                        1)
            */
              
            { using XINPUT
              newController.lStick[.x] = wProccesStickDeadzone(pad.sThumbLX, GAMEPAD_LEFT_THUMB_DEADZONE)
              newController.lStick[.y] = -wProccesStickDeadzone(pad.sThumbLY, GAMEPAD_LEFT_THUMB_DEADZONE)
              newController.rStick[.x] = wProccesStickDeadzone(pad.sThumbRX, GAMEPAD_RIGHT_THUMB_DEADZONE)
              newController.rStick[.y] = -wProccesStickDeadzone(pad.sThumbRY, GAMEPAD_RIGHT_THUMB_DEADZONE)
            }
            



            /* TODO(Carbon) Does this have to be round trippy?
            vibration : XINPUT.VIBRATION 
            vibration.wRightMotorSpeed = 
            vibration.wLeftMotorSpeed = 
            XINPUT.SetState(i, &vibration)
            */

          } else {
            //NOTE (Carbon): Controller is not avaliable
            newController.isConnected = false
          }
          
          break
        }

        if globalState.pause do continue
        
        colorBuffer : game_offscreen_buffer
        colorBuffer.memory = globalState.buffer.memory
        colorBuffer.width  = globalState.buffer.width
        colorBuffer.height = globalState.buffer.height
        colorBuffer.pitch  = globalState.buffer.pitch

        if recordingState.inputRecordingIndex != 0 {
          wInputRecord(&recordingState, newInput)
        }
        if recordingState.inputPlayingIndex != 0 {
          wInputPlayback(&recordingState, newInput, recordingState.fileLocation)
        }

        game.UpdateAndRender(&gameMemory, &colorBuffer, newInput)

        //Padding is how much valid data is queued up in the sound buffer
        //NOTE(Carbon): One frame is 2 channels at 16 bits, so total of 4 bytes
        bufferPadding: u32
        globalState.audio.client->GetCurrentPadding(&bufferPadding)
        nFramesToWrite := globalState.audio.bufferSizeFrames - bufferPadding
        //nFramesToWrite :=  u32(f32(soundBuffer.samplesPerSecond) * targetSecondsPerFrame * 1.1)  
        soundBuffer : game_sound_output_buffer
        soundBuffer.samples = samples // Allocated before after init
        soundBuffer.samplesPerSecond = globalState.audio.samplesPerSecond 
        soundBuffer.sampleCount = int(nFramesToWrite)
        game.GetSoundSamples(&gameMemory, &soundBuffer) 
        //TODO(Carbon) figure out how the constant below effects buffer with 
        //             a displayblable debug. Seems That we need a fairly high 
        //             audio latency

        { //Write audio to buffer
          buffer: ^i8
          globalState.audio.renderClient->GetBuffer(nFramesToWrite, cast(^^BYTE)&buffer)

          if nFramesToWrite > 0 && buffer != nil{
            MEM.copy(buffer, soundBuffer.samples, int(nFramesToWrite) * 4)
          }

          globalState.audio.renderClient->ReleaseBuffer(nFramesToWrite, 0)
        }


        deviceContext := GetDC(window)

        windowWidth, windowHeight  := wWindowDemensions(window)
        wDisplayBufferInWindow(deviceContext, windowWidth, windowHeight, &globalState.buffer)

        ReleaseDC(window, deviceContext)

        temp: ^game_input = newInput
        newInput = oldInput
        oldInput = temp

        secondsElapsedForFrame := wGetSecondsElapsed(prevCounter, wGetWallClock()) //NOTE Keep at end before sleep

        if secondsElapsedForFrame < targetSecondsPerFrame {
          for secondsElapsedForFrame < targetSecondsPerFrame {
            if sleepIsGranular {
              sleepMS : DWORD = cast(DWORD)(1000 * f32(targetSecondsPerFrame - secondsElapsedForFrame))
              Sleep(sleepMS)
            }
            secondsElapsedForFrame = wGetSecondsElapsed(prevCounter, wGetWallClock())
          }
        } else { 
          //TODO(Carbon): Log
        }

        when #config(PRINT, true) { //TODO(Carbon): Better logging system
          //Locked frame time: FMT.println(wGetSecondsElapsed(prevCounter, wGetWallClock()))
        }

        prevCyclesCount = INTRINSICS.read_cycle_counter()
        prevCounter = wGetWallClock() 

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

wInputBeginRecording :: proc(state: ^recording_state, 
                             inputRecordingIndex : int,
                             filename: string){
  using WIN32

  state.inputRecordingIndex = inputRecordingIndex

  filename_w: [dynamic]u16
  append(&filename_w, 0)
  for letter in filename{
    append(&filename_w, 0)
  }
  UTF16.encode_string(filename_w[:], filename)

  state.recordingHandle = CreateFileW( &filename_w[0], GENERIC_WRITE, 
                                       0, nil, CREATE_ALWAYS, 0, nil)

  bytesWritten := cast(u32)state.totalBlockSize
  //NOTE(Carbon) windows only accepts 32 bit writes, once its larger we have to 
  //             loop. Asserting failure for now
  assert(u64(bytesWritten) == state.totalBlockSize)
  WriteFile(state.recordingHandle, state.gameMemoryBlock, 
            u32(state.totalBlockSize), &bytesWritten, nil)
}

wInputEndRecording :: proc(state: ^recording_state){
  WIN32.CloseHandle(state.recordingHandle)
  state.inputRecordingIndex = 0
}

wInputRecord :: proc(state: ^recording_state, newInput: ^game_input ) {
  using WIN32
  bytesWritten : DWORD
  WriteFile(state.recordingHandle, newInput, size_of(newInput^), &bytesWritten, nil)
}

wInputBeginPlayback :: proc(state: ^recording_state,
                            inputPlayingIndex: int,
                            filename: string  ){
  using WIN32

  state.inputPlayingIndex = inputPlayingIndex

  filename_w: [dynamic]u16
  append(&filename_w, 0)
  for letter in filename{
    append(&filename_w, 0)
  }
  UTF16.encode_string(filename_w[:], filename)

  state.playbackHandle = CreateFileW( &filename_w[0], GENERIC_READ, FILE_SHARE_READ,
  nil, OPEN_EXISTING, 0, nil)

  bytesRead : DWORD
  result := ReadFile(state.playbackHandle, state.gameMemoryBlock, 
                     u32(state.totalBlockSize), &bytesRead, nil)
}

wInputEndPlayback :: proc(state: ^recording_state) {
  WIN32.CloseHandle(state.playbackHandle)
  state.inputPlayingIndex = 0
}

wInputPlayback :: proc(state: ^recording_state, newInput: ^game_input, filepath: string ) {
  using WIN32
  bytesRead : DWORD
  result := ReadFile(state.playbackHandle, newInput, size_of(newInput^), &bytesRead, nil)
  if bytesRead < size_of(newInput^) && result {
    playingIndex := state.inputPlayingIndex
    wInputEndPlayback(state)
    wInputBeginPlayback(state, playingIndex, filepath)
    ReadFile(state.playbackHandle, newInput, size_of(newInput^), &bytesRead, nil)
  }
}

wGetSecondsElapsed :: proc(start, end: WIN32.LARGE_INTEGER) -> (result: f32) {
  result = f32(f32(end - start) / f32(globalState.perfCountFrequency))
  return
}

wGetWallClock :: proc() -> (result: WIN32.LARGE_INTEGER) {
  WIN32.QueryPerformanceCounter(&result)
  return
}

wWindowCallback :: proc "std" (window: WIN32.HWND  , message: WIN32.UINT,
                                   wParam: WIN32.WPARAM, lParam : WIN32.LPARAM) -> 
                                  WIN32.LRESULT {

  using WIN32
  result : LRESULT = 0
  switch(message) {
    case WM_QUIT:       fallthrough
    case WM_SYSKEYDOWN: fallthrough
    case WM_SYSKEYUP:   fallthrough
    case WM_KEYDOWN:    fallthrough
    case WM_KEYUP:
    //TODO(carbon) Assert failure here, can't due to Odin's context system.
    //             Learn about odin's contexts

    case WM_DESTROY:
      globalState.running = false
      //TODO(Carbon) Handle as an error?

    case WM_CLOSE:
      globalState.running = false
      //TODO(Carbon) Possibly message/warn user.

    case WM_ACTIVATEAPP:
      if(bool(wParam) == true) {
        SetLayeredWindowAttributes(window, RGB(0,0,0) , 255, 0x2) //LWA_ALPHA
      } else {
        SetLayeredWindowAttributes(window, RGB(0,0,0) , 70, 0x2) //LWA_ALPHA
      }

    case WM_PAINT:
      paint : PAINTSTRUCT
      deviceContext := BeginPaint(window, &paint)
      x      :=  paint.rcPaint.left
      y      :=  paint.rcPaint.top
      height :=  paint.rcPaint.bottom - paint.rcPaint.top
      width  :=  paint.rcPaint.right  - paint.rcPaint.left

      windowWidth, windowHeight := wWindowDemensions(window)  
      wDisplayBufferInWindow(deviceContext, windowWidth, windowHeight, &globalState.buffer)
      EndPaint(window, &paint)

      
    case: //Default
      result = DefWindowProcW(window, message, wParam, lParam)
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
    //0, 0, windowWidth, windowHeight, 
    //NOTE(Carbon) Doing direct mapping for 1 to 1 pixels while coding renderer
    0, 0, bitmap.width, bitmap.height,
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


wInitAudio :: proc(audio: ^w_audio) -> bool {

      hr := WIN32.CoInitializeEx(nil, WIN32.COINIT.SPEED_OVER_MEMORY)
      if hr != S_OK { return false }

      deviceEnumerator : ^WASAPI.IMMDeviceEnumerator
      hr = WIN32.CoCreateInstance(
        &WASAPI.CLSID_MMDeviceEnumerator,
        nil,
        WASAPI.CLSCTX_ALL,
        WASAPI.IMMDeviceEnumerator_UUID,
        cast(^rawptr)&deviceEnumerator,
      )
      if hr != S_OK { return false }
      defer deviceEnumerator->Release()

      //TODO (Carbon): Change this to device collection so users can choose 
      //               what audio device they want to use.
      //TODO(Carbon):  Use property stope to get name for device/s
      audioDevice: ^WASAPI.IMMDevice
      hr = deviceEnumerator->GetDefaultAudioEndpoint(WASAPI.EDataFlow.eRender,
                                                      WASAPI.ERole.eConsole,
                                                      &audioDevice)
      if hr != S_OK { return false }
      defer audioDevice->Release()

      hr = audioDevice->Activate(WASAPI.IAudioClient2_UUID,
                                  WASAPI.CLSCTX_ALL, nil
                                  cast(^rawptr)&audio.client)
      if hr != S_OK { return false }


      /*NOTE(Carbon): Trying GetMixFormat causes audio to not play.
      mix_format : ^WASAPI.WAVEFORMATEX
      audio.client->GetMixFormat(&mix_format)
      
      This is the recommended thing to do, but I can't seem to get it to work
      correctly.
      */

      mix_format: WASAPI.WAVEFORMATEX = {
        wFormatTag      = 1, // WAVE_FORMAT_PCM, as we only need two channel
        nChannels       = 2,  
        nSamplesPerSec  = 48000,
        wBitsPerSample  = 16,
        nBlockAlign     = 2 * 16 / 8, // nChannel * wBitsPerSample / 8 bits
        nAvgBytesPerSec = 48000 * 2 * 16 / 8, //nSamplesPerSec * nBlockAlign
      }

      init_stream_flags : u32 = WASAPI.AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                          WASAPI.AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY|
                          WASAPI.AUDCLNT_STREAMFLAGS_RATEADJUST


      REFTIMES_PER_SEC :: 1000 //every milisecond?
      requested_buffer_duration: i64 = REFTIMES_PER_SEC
      hr = audio.client->Initialize(WASAPI.AUDCLNT_SHAREMODE.SHARED,
                                    init_stream_flags,
                                    requested_buffer_duration
                                    0,
                                    &mix_format,
                                    nil)


      hr = audio.client->GetService(WASAPI.IAudioRenderClient_UUID,
                                   cast(^rawptr)&audio.renderClient)

      audio.samplesPerSecond = mix_format.nSamplesPerSec
      audio.bytesPerSample   = mix_format.wBitsPerSample / 8

      defaultPeriod: WASAPI.REFERENCE_TIME
      minPeriod: WASAPI.REFERENCE_TIME
      audio.client->GetDevicePeriod(&defaultPeriod, &minPeriod)

      hr = audio.client->GetBufferSize(&audio.bufferSizeFrames)
      hr = audio.client->Start()
      return true
}
   
@private 
wProcessXInputDigitalButton :: proc(XInputButtonState: WIN32.WORD,
                                   newState, oldState: ^game_button_state, 
                                   buttonBit: WIN32.WORD) {
  newState.endedDown = bool(XInputButtonState & buttonBit)
  oldState.transitionCount = 1 if (oldState.endedDown != newState.endedDown) else 0
}

wProcessKeyboardMessage :: proc(keyboardState: ^game_button_state,
                              isDown: bool) {
  //TODO(Carbon) Why is this procing when we should be stopping key repeats?
  assert(keyboardState.endedDown != isDown, "function shouldn't be called unless there was a transition.")
  keyboardState.endedDown = isDown;
  keyboardState.transitionCount += 1
}

wHandlePendingMessages :: proc(recordingState: ^recording_state,
                               keyboardController: ^game_controller_input) {
  using WIN32 
   
  message: MSG
  for PeekMessageW(&message, nil, 0, 0, PM_REMOVE) {

    switch message.message {
      case WM_QUIT: 
        globalState.running = false;
         
      case WM_SYSKEYDOWN: fallthrough
      case WM_SYSKEYUP: fallthrough
      case WM_KEYDOWN: fallthrough
      case WM_KEYUP:
        
        VKCode  := u32(message.wParam)
        wasDown := bool(message.lParam & ( 1 << 30) != 0)
        isDown  := bool(message.lParam & ( 1 << 31) == 0)
        altDown := bool(message.lParam & ( 1 << 29) != 0)

        //Stop Key Repeating
        if wasDown != isDown {
          switch VKCode {
            case 'W': 
              wProcessKeyboardMessage(&keyboardController.buttons[.move_up], isDown)
            case 'A': 
              wProcessKeyboardMessage(&keyboardController.buttons[.move_left], isDown)
            case 'S': 
              wProcessKeyboardMessage(&keyboardController.buttons[.move_down], isDown)
            case 'D': 
              wProcessKeyboardMessage(&keyboardController.buttons[.move_right], isDown)

            case 'Q': 
              wProcessKeyboardMessage(&keyboardController.buttons[.shoulder_left], isDown)
            case 'E': 
              wProcessKeyboardMessage(&keyboardController.buttons[.shoulder_right], isDown)

            case 'L':
              if isDown {
                if recordingState.inputRecordingIndex == 0 {
                  wInputBeginRecording(recordingState, 1, recordingState.fileLocation)
                } else {
                  wInputEndRecording(recordingState)
                  wInputBeginPlayback(recordingState, 1, recordingState.fileLocation)
                }
              }

            case VK_UP:
            case VK_LEFT:
            case VK_DOWN:
            case VK_RIGHT:
            case globalState.controls.close:
              wProcessKeyboardMessage(&keyboardController.buttons[.back], isDown)
              globalState.running = false
            case VK_SPACE:
              wProcessKeyboardMessage(&keyboardController.buttons[.start], isDown)
            case VK_F4:
              if altDown do globalState.running = false

            case 'P':
              when #config(INTERNAL, true) do globalState.pause = true 
            case 'C':
              when #config(INTERNAL, true) do globalState.pause = false

          }
        }

      case: //Default
        TranslateMessage(&message)
        DispatchMessageW(&message)

    }
  }
}

wProccesStickDeadzone :: proc(stickValue: WIN32.SHORT, 
                              deadZone: WIN32.SHORT) -> (result: f32) {

  if stickValue < -deadZone {
    result = f32(stickValue) / 32768 
  }
  else if stickValue > deadZone {
    result = f32(stickValue) / 32767 
  }

  return
}

game_code :: struct {
  isValid         : bool
  library         : DLIB.Library
  lastWriteTime   : OS.File_Time

  UpdateAndRender : proc(gameMemory:   ^game_memory, 
                         colorBuffer : ^game_offscreen_buffer, 
                         gameControls: ^game_input) 
  GetSoundSamples : proc( memory: ^game_memory, 
                          soundBuffer: ^game_sound_output_buffer) 
}


wLoadGameCode :: proc(dllName, dllTempName: string) -> game_code {

  result : game_code
  lastWriteTime, er := OS.last_write_time_by_name(dllName) 
  result.lastWriteTime = lastWriteTime

  //TODO(Carbon): Have to create tmp pdb files for debugger hot reloading.
  //NOTE(Carbon): Have to constantly read file until is succeed. For some reason
  //              it likes to not work. See if you can get CopyFileExW to work.
  success := false 
  dll : []u8
  for !success {
    dll, success = OS.read_entire_file_from_filename(dllName)
  }
  OS.write_entire_file(dllTempName, dll, true)


  lib, ok:= DLIB.load_library(dllTempName)
  if ok {
    result.isValid = true 
    result.library = lib
    tmp := DLIB.symbol_address( lib, "gameUpdateAndRender")
    result.UpdateAndRender = cast( proc(gameMemory:   ^game_memory, 
                                      colorBuffer : ^game_offscreen_buffer, 
                                      gameControls: ^game_input))tmp
    tmp = DLIB.symbol_address( lib, "gameGetSoundSamples")
    result.GetSoundSamples = cast( proc( memory: ^game_memory, 
                                       soundBuffer: ^game_sound_output_buffer))tmp
  } else {
    result.UpdateAndRender = empty_UpdateAndRender
    result.GetSoundSamples = empty_GetSoundSamples
  }
  return result
}

wUnloadGameCode :: proc(gameCode: ^game_code) {

  DLIB.unload_library(gameCode.library)
  gameCode.isValid = false
  gameCode.UpdateAndRender = empty_UpdateAndRender
  gameCode.GetSoundSamples = empty_GetSoundSamples
}


when #config(INTERNAL, true) {

  //NOTE(Carbon) Don't used for shipped game. Locks and not thread safe. 
  //             Doesn't protext lost data

  DEBUG_read_file_result :: struct {
    contentsSize: u32
    contents: rawptr
  }

  DEBUG_platformReadEntireFile :: proc(filename: string) -> (DEBUG_read_file_result, bool) {
    using WIN32

    result : DEBUG_read_file_result
    success := false

    filename_w: [dynamic]u16
    append(&filename_w, 0)
    for letter in filename{
      append(&filename_w, 0)
    }

    UTF16.encode_string(filename_w[:], filename)
    fileHandle := CreateFileW( &filename_w[0], GENERIC_READ, FILE_SHARE_READ,
                                nil, OPEN_EXISTING, 0, nil)

    if fileHandle != INVALID_HANDLE_VALUE {
      defer CloseHandle(fileHandle)


      fileSize: LARGE_INTEGER
      if GetFileSizeEx(fileHandle, &fileSize) {
        result.contents = VirtualAlloc(
          nil,
          uint(fileSize),
          MEM_RESERVE | MEM_COMMIT,
          PAGE_READWRITE,)
           
        if result.contents != nil {
          fileSize32 := HELPER.safeTruncateU64(u64(fileSize))
          bytesRead : DWORD
          if ReadFile( fileHandle, result.contents, fileSize32, &bytesRead, nil) && 
             bytesRead == fileSize32 {
               result.contentsSize = fileSize32
               success = true
          } else {
            DEBUG_platformFreeFileMemory(result.contents)
            result.contents, success = nil, false
          }
        }
      }
    }

    return result, success
  }

  DEBUG_platformFreeFileMemory :: proc(memory: rawptr) {
    using WIN32
    if memory != nil do WIN32.VirtualFree(memory, 0, MEM_RELEASE)
    return
  }


  DEBUG_platformWriteEntireFile :: proc(filename: string, memorySize: u32,
                                        memory: rawptr) -> bool {
    using WIN32

    result := false

    filename_w: [dynamic]u16
    append(&filename_w, 0)
    for letter in filename{
      append(&filename_w, 0)
    }

    UTF16.encode_string(filename_w[:], filename)

    fileHandle := CreateFileW( &filename_w[0], GENERIC_WRITE, 0,
                                nil, CREATE_ALWAYS, 0, nil)

    if fileHandle != INVALID_HANDLE_VALUE {
      defer CloseHandle(fileHandle)

      bytesWritten : DWORD
      if WriteFile( fileHandle, memory, memorySize, &bytesWritten, nil) {
        result = (bytesWritten == memorySize)
      } else {
      }
    }
    return result 
  }

}
catString :: proc(start, end: string) -> string {
  start_b := transmute([]u8)start
  end_b := transmute([]u8)end

  buffer : [dynamic]u8
  index := 0
  for byte in start_b {
    append(&buffer, byte)
    index += 1
    if start[index] == 0 do break
  }
  for byte in end_b {
    append(&buffer, byte)
    index += 1
  }

  result := string(buffer[:])
  return result
}

