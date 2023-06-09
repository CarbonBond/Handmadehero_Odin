package helper

import UTF16  "core:unicode/utf16"
import WIN32  "core:sys/windows"

MessageBox :: proc(text, caption: string) {
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

kilobytes :: proc(num: u64) -> u64 {
  return num * 1024
}
megabytes :: proc(num: u64) -> u64 {
  return num * 1024 * 1024
}
gigabytes :: proc(num: u64) -> u64 {
  return num * 1024 * 1024 * 1024
}
terabytes :: proc(num: u64) -> u64 {
  return num * 1024 * 1024 * 1024 * 1024
}


safeTruncateU64 :: proc(value: u64) -> u32 {
  assert( value <= 0xFFFFFFFF, "filesize is too big to read")
  return u32(value)
}
