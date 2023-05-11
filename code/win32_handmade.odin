package main

import FMT "core:fmt"
import UTF16 "core:unicode/utf16"
import WIN32 "core:sys/windows"

main :: proc() {

  wMessageBox("A message!", "Handmade Hero")

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
  WIN32.MessageBoxW(nil, &lpText_w[0], &lpCaption_w[0], WIN32.MB_OK|WIN32.MB_ICONINFORMATION)
}
