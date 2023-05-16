package main

import FMT     "core:fmt"
import UTF16   "core:unicode/utf16"
import WIN32   "core:sys/windows"
import XINPUT  "xinput" 
import WAVEOUT "audio/wasapi"
import H       "helper"

foreign import gdi32 "system:Gdi32.lib"
foreign gdi32 {
    CreateCompatibleDC :: proc "stdcall" (hdc : WIN32.HDC) -> WIN32.HDC ---
}


// TODO(Carbon) Change from global
@private
running            : bool
globalBuffer       : w_offscreen_buffer


w_offscreen_buffer :: struct {
        memory        : [^]u32
        info          : WIN32.BITMAPINFO 
        width         : i32
        height        : i32
        pitch         : i32
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

wResizeDIBSection :: proc "contextless" (bitmap: ^w_offscreen_buffer, 
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

wDisplayBufferInWindow :: proc "contextless" (deviceContext: WIN32.HDC, 
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

wRenderWeirdGradiant :: proc "contextless" (bitmap: ^w_offscreen_buffer,
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

wWindowDemensions :: proc "contextless" (window : WIN32.HWND) -> (width, height: i32) {
        clientRect: WIN32.RECT 
        WIN32.GetClientRect(window, &clientRect)
        width  = clientRect.right - clientRect.left
        height = clientRect.bottom - clientRect.top
        return
}

