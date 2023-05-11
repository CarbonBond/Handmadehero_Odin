package main

import FMT "core:fmt"
import UTF16 "core:unicode/utf16"
import WIN32 "core:sys/windows"

main :: proc() {

  lpText :: "Message!"
  lpCaption :: "Title!"
  lpText_w : [len(lpText)+1]u16
  lpCaption_w : [len(lpCaption)+1]u16
  UTF16.encode_string(lpText_w[:], lpText)
  UTF16.encode_string(lpCaption_w[:], lpCaption)
  WIN32.MessageBoxW(nil, &lpText_w[0], &lpCaption_w[0], WIN32.MB_OK|WIN32.MB_ICONINFORMATION)
  
}
