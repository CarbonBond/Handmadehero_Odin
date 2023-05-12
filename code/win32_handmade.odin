package main

import FMT "core:fmt"
import UTF16 "core:unicode/utf16"
import WIN32 "core:sys/windows"

foreign import gdi32 "system:Gdi32.lib"
foreign gdi32 {
    CreateCompatibleDC :: proc "stdcall" (hdc : WIN32.HDC) -> WIN32.HDC ---
}


// TODO(Carbon) Change from global
@private
running      : bool
bitmapInfo   : WIN32.BITMAPINFO 
bitmapMemory : rawptr
bitmapWidth  : i32
bitmapHeight : i32

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
    if window!= nil  {
      
      message: WIN32.MSG
      running = true 

      for running {
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
    //TODO(Carbon) Uses custom logging if CreateWindow failed
    }

  } else {
      wMessageBox("Register Class Fail!", "Handmade Hero")
  //TODO(Carbon) Uses custom logging if RegisterClass failed
  }
}

wWindowCallback :: proc "stdcall" (window: WIN32.HWND  , message: WIN32.UINT,
                                   wParam: WIN32.WPARAM, lParam : WIN32.LPARAM) -> 
                                  WIN32.LRESULT {
  result : WIN32.LRESULT = 0
  switch(message) {
    case WIN32.WM_SIZE:
      clientRect : WIN32.RECT 
      WIN32.GetClientRect(window, &clientRect)
      width  := clientRect.right - clientRect.left
      height := clientRect.bottom - clientRect.top
      wResizeDIBSection(width, height)
      WIN32.OutputDebugStringA("WM_SIZE\n")

    case WIN32.WM_DESTROY:
      WIN32.OutputDebugStringA("WM_DESTROY\n")
      running = false
      //TODO(Carbon) Handle as an error?

    case WIN32.WM_CLOSE:
      WIN32.OutputDebugStringA("WM_CLOSE\n")
      running = false
      //TODO(Carbon) Possibly message/warn user.

    case WIN32.WM_ACTIVATEAPP:
      WIN32.OutputDebugStringA("WM_ACTIVATEAPP\n")

    case WIN32.WM_PAINT:
      paint : WIN32.PAINTSTRUCT
      deviceContext := WIN32.BeginPaint(window, &paint)
      x      :=  paint.rcPaint.left
      y      :=  paint.rcPaint.top
      height :=  paint.rcPaint.bottom - paint.rcPaint.top
      width  :=  paint.rcPaint.right  - paint.rcPaint.left

      clientRect : WIN32.RECT 
      WIN32.GetClientRect(window, &clientRect)

      wUpdateWindow(deviceContext, &clientRect, x, y, width, height)
      WIN32.EndPaint(window, &paint)

    case: //Default
      result = WIN32.DefWindowProcW(window, message, wParam, lParam)
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

wResizeDIBSection :: proc "contextless" (width, height: i32) {

  if bitmapMemory != nil {
    WIN32.VirtualFree(bitmapMemory, 0, WIN32.MEM_RELEASE)
  }

  bitmapHeight = height
  bitmapWidth  = width

  bitmapInfo.bmiHeader.biSize = size_of(bitmapInfo.bmiHeader)
  bitmapInfo.bmiHeader.biWidth          = bitmapWidth
  bitmapInfo.bmiHeader.biHeight         = -bitmapHeight
  bitmapInfo.bmiHeader.biPlanes         = 1
  bitmapInfo.bmiHeader.biBitCount       = 32
  bitmapInfo.bmiHeader.biCompression    = WIN32.BI_RGB

  bytesPerPixel :: 4
  bitmapSize    := uint(bytesPerPixel * width * height)
  WIN32.VirtualAlloc(nil, bitmapSize, WIN32.MEM_COMMIT, WIN32.PAGE_READWRITE)

}

wUpdateWindow :: proc "contextless" (deviceContext: WIN32.HDC, windowRect: ^WIN32.RECT, x, y, width, height: i32) {

  windowWidth  := windowRect.right  - windowRect.left
  windowHeight := windowRect.bottom - windowRect.top

  WIN32.StretchDIBits(
    deviceContext,
    /*
    x, y, width, height,
    x, y, width, height,
    */
    0, 0, bitmapWidth, bitmapHeight,
    0, 0, windowWidth, windowHeight,
    bitmapMemory,
    &bitmapInfo,
    WIN32.DIB_RGB_COLORS,
    WIN32.SRCCOPY
  )

}
