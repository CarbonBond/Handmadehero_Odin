package wingdi

import WIN32 "core:sys/windows"

foreign import wingdi "system:Gdi32.lib"
foreign wingdi  {
  GetDeviceCaps :: proc "std" ( hdc: WIN32.HDC, index: int) -> int ---
}


VREFRESH  :: 116  
