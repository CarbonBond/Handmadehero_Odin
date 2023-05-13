package main

import FMT   "core:fmt"
import UTF16 "core:unicode/utf16"
import WIN32 "core:sys/windows"

foreign import gdi32 "system:Gdi32.lib"
foreign gdi32 {
    CreateCompatibleDC :: proc "stdcall" (hdc : WIN32.HDC) -> WIN32.HDC ---
}


// TODO(Carbon) Change from global
@private
running  : bool
buffer   : w_offscreen_buffer

w_offscreen_buffer:: struct {
  info          : WIN32.BITMAPINFO 
  memory        : [^]u32
  width         : i32
  height        : i32
  pitch         : i32
}


main :: proc() {

  instance := cast(WIN32.HINSTANCE)WIN32.GetModuleHandleA(nil)

  windowClass :               WIN32.WNDCLASSW
  windowClass.style         = WIN32.CS_HREDRAW | WIN32.CS_VREDRAW
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
      
      blueOffset : i32 = 0
      greenOffset : i32 = 0

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

        wRenderWeirdGradiant(&buffer, greenOffset, blueOffset)

        deviceContext := WIN32.GetDC(window)
        clientRect: WIN32.RECT 
        WIN32.GetClientRect(window, &clientRect)
        windowWidth  := clientRect.right - clientRect.left
        windowHeight := clientRect.bottom - clientRect.top
        wDisplayBufferInWindow(deviceContext, clientRect, &buffer
                      0, 0, windowWidth, windowHeight)
        WIN32.ReleaseDC(window, deviceContext)

        greenOffset += 1
        blueOffset += 1
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
      wResizeDIBSection(&buffer, width, height)
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

      wDisplayBufferInWindow(deviceContext, clientRect, &buffer
                    x, y, width, height)
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


  wRenderWeirdGradiant(bitmap, 128, 0)

}

wDisplayBufferInWindow :: proc "contextless" (deviceContext: WIN32.HDC, 
                                     windowRect: WIN32.RECT,
                                     bitmap: ^w_offscreen_buffer,
                                     x, y, width, height: i32) {

  windowWidth  := windowRect.right  - windowRect.left
  windowHeight := windowRect.bottom - windowRect.top

  WIN32.StretchDIBits(
    deviceContext,
    /*
    x, y, width, height,
    x, y, width, height,
    */
    0, 0, bitmap.width, bitmap.height,
    0, 0, windowWidth, windowHeight,
    bitmap.memory,
    &bitmap.info,
    WIN32.DIB_RGB_COLORS,
    WIN32.SRCCOPY
  )

}

wRenderWeirdGradiant :: proc "contextless" (bitmap: ^w_offscreen_buffer,
                                            greenOffset, blueOffset: i32) {

  bitmapMemoryArray := bitmap.memory[:]
  size := bitmap.pitch * bitmap.height
  row : i32 = 0
  for y : i32 = 0; y < bitmap.height; y += 1 {
    pixel := row
    for x : i32 = 0; x < bitmap.width; x += 1 {
      red   : u8 = u8(x*y)
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
