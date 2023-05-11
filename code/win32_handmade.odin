package main

import FMT "core:fmt"
import UTF16 "core:unicode/utf16"
import WIN32 "core:sys/windows"

main :: proc() {

  instance := cast(WIN32.HINSTANCE)WIN32.GetModuleHandleA(nil)

  windowClass : WIN32.WNDCLASSW
  windowClass.style         = WIN32.CS_OWNDC | WIN32.CS_HREDRAW | WIN32.CS_VREDRAW
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
    windowHandle : WIN32.HWND = WIN32.CreateWindowExW(
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
    if windowHandle != nil  {
      
      message: WIN32.MSG
      for true {
        messageResult := WIN32.GetMessageW(&message, nil, 0, 0)
        if int(messageResult) > 0 {
          WIN32.TranslateMessage(&message)
          WIN32.DispatchMessageW(&message)
        } else {
          break
        }
      }

    } else {
      wMessageBox("Create Window Fail!", "Handmade Hero")

    //TODO(Carbon) Log if CreateWindow failed
    }

  } else {
      wMessageBox("Register Class Fail!", "Handmade Hero")
  //TODO(Carbon) Log if RegisterClass failed
  }
}

wWindowCallback :: proc "stdcall" (windowHandle: WIN32.HWND  , message: WIN32.UINT,
                                   wParam: WIN32.WPARAM, lParam : WIN32.LPARAM) -> 
                                  WIN32.LRESULT {
  result : WIN32.LRESULT = 0
  switch(message) {
    case WIN32.WM_SIZE:
      WIN32.OutputDebugStringA("WM_SIZE\n")

    case WIN32.WM_DESTROY:
      WIN32.OutputDebugStringA("WM_DESTROY\n")

    case WIN32.WM_CLOSE:
      WIN32.PostQuitMessage(0)
      WIN32.OutputDebugStringA("WM_CLOSE\n")

    case WIN32.WM_ACTIVATEAPP:
      WIN32.OutputDebugStringA("WM_ACTIVATEAPP\n")

    case WIN32.WM_PAINT:
      paint : WIN32.PAINTSTRUCT
      deviceContext := WIN32.BeginPaint(windowHandle, &paint)
      height :=  paint.rcPaint.bottom - paint.rcPaint.top
      width  :=  paint.rcPaint.right  - paint.rcPaint.left
      x      :=  paint.rcPaint.left
      y      :=  paint.rcPaint.top
      WIN32.PatBlt(deviceContext, x, y, width, height, WIN32.BLACKNESS)
      WIN32.EndPaint(windowHandle, &paint)

    case:
      result = WIN32.DefWindowProcW(windowHandle, message, wParam, lParam)
  }

  return result
}

wMessageBox :: proc(text, caption: string) {
  lpText_w : [dynamic]u16
  append(&lpText_w, 0)
  for letter in text {
    append(&lpText_w, 0)
  }
  lpCaption_w : [dynamic]u16
    append(&lpCaption_w, 0)
  for letter in caption {
    append(&lpCaption_w, 0)
  }

  UTF16.encode_string(lpText_w[:], text)
  UTF16.encode_string(lpCaption_w[:], caption)
  WIN32.MessageBoxW(nil, &lpText_w[0], &lpCaption_w[0],
                    WIN32.MB_OK|WIN32.MB_ICONINFORMATION)
}

