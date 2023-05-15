package xinput

import WIN32  "core:sys/windows"
import H "../helper"
import DLIB "core:dynlib"
foreign import xinput "system:xinput.lib"

//************************ FUNCTIONS **************************//
foreign xinput {
  XInputEnable :: proc(enable: WIN32.BOOL) ---
  /* Remarks
    Pasing False will stop any vibration effects.
    Pasing True will 
  */
}
foreign xinput {
  XInputGetAudioDeviceIds :: proc(
    dwUserIndex:       WIN32.DWORD,  
    pRenderDeviceId:   WIN32.LPWSTR,
    pRenderCount:     ^WIN32.UINT,
    pCaptureDeviceId:  WIN32.LPWSTR,
    pCaptureCount:    ^WIN32.UINT) -> WIN32.DWORD ---
}
foreign xinput {
  XInputGetBatteryInformation :: proc(
    dwUserIndex:          WIN32.DWORD,
    devtype:              WIN32.BYTE,
    pBatteryInformation: ^BATTERY_INFORMATION) -> WIN32.DWORD  ---
}
foreign xinput {
  XInputGetCapabilities :: proc(
    dwUserIndex:    WIN32.DWORD,
    dwFlags:        WIN32.DWORD,
    pCapabilities: ^CAPABILITIES) -> WIN32.DWORD ---
}
foreign xinput {
  XInputGetDSoundAudioDeviceGuids :: proc(
    dwUserIndex:        WIN32.DWORD,
    pDSoundRenderGuid:  ^WIN32.GUID,
    pDSoundCaptureGuid: ^WIN32.GUID) -> WIN32.DWORD ---
}
foreign xinput {
  XInputGetKeystoke :: proc(
    dwUserIndex: WIN32.DWORD,
    dwReserved:  WIN32.DWORD,
    pKeyStroke: ^KEYSTROKE) -> WIN32.DWORD ---
}
foreign xinput {
  XInputGetState :: proc "stdcall" (
    dwUserIndex: WIN32.DWORD,
    pState:     ^STATE) -> WIN32.DWORD --- 
}
foreign xinput {
  XInputSetState :: proc(
  dwUserIndex: WIN32.DWORD,
  pVibration: ^VIBRATION) -> WIN32.DWORD ---
}

// Multiple DLL loading

Enable : proc(WIN32.BOOL)

GetState : proc(WIN32.DWORD, ^STATE) -> WIN32.DWORD

GetAudioDeviceIds : proc( WIN32.DWORD,  WIN32.LPWSTR, ^WIN32.UINT, 
                          WIN32.LPWSTR, ^WIN32.UINT) -> WIN32.DWORD

GetBatteryInformation : proc( WIN32.DWORD, WIN32.BYTE,
                             ^BATTERY_INFORMATION) -> WIN32.DWORD 

GetCapabilities : proc( WIN32.DWORD,WIN32.DWORD, ^CAPABILITIES) -> WIN32.DWORD 

GetDSoundAudioDeviceGuids : proc( WIN32.DWORD, ^WIN32.GUID, 
                                 ^WIN32.GUID) -> WIN32.DWORD 

GetKeystroke :proc( WIN32.DWORD, WIN32.DWORD, ^KEYSTROKE) -> WIN32.DWORD 

SetState : proc( WIN32.DWORD, ^VIBRATION) -> WIN32.DWORD 

// Failsafe empty functions 

GetStateNothing :: proc(dwUserIndex: WIN32.DWORD, 
                        pState: ^STATE) -> WIN32.DWORD { return 1 }
EnableNothing :: proc(enable: WIN32.BOOL) { return } 
GetAudioDeviceIdsNothing :: proc(
  dwUserIndex:       WIN32.DWORD,  
  pRenderDeviceId:   WIN32.LPWSTR,
  pRenderCount:     ^WIN32.UINT,
  pCaptureDeviceId:  WIN32.LPWSTR,
  pCaptureCount:    ^WIN32.UINT) -> WIN32.DWORD { return 1 }
GetBatteryInformationNothing :: proc(
  dwUserIndex:          WIN32.DWORD,
  devtype:              WIN32.BYTE,
  pBatteryInformation: ^BATTERY_INFORMATION) -> WIN32.DWORD { return 1 } 
GetCapabilitiesNothing :: proc(
  dwUserIndex:    WIN32.DWORD,
  dwFlags:        WIN32.DWORD,
  pCapabilities: ^CAPABILITIES) -> WIN32.DWORD { return 1 }
GetDSoundAudioDeviceGuidsNothing :: proc(
  dwUserIndex:        WIN32.DWORD,
  pDSoundRenderGuid:  ^WIN32.GUID,
  pDSoundCaptureGuid: ^WIN32.GUID) -> WIN32.DWORD { return 1 }

GetKeystokeNothing :: proc(
  dwUserIndex: WIN32.DWORD,
  dwReserved:  WIN32.DWORD,
  pKeyStroke: ^KEYSTROKE) -> WIN32.DWORD { return 1 }

SetStateNothing :: proc(
dwUserIndex: WIN32.DWORD,
pVibration: ^VIBRATION) -> WIN32.DWORD { return 1 }

@init
init :: proc() {
  lib : DLIB.Library
  ok  : bool
  //Load Xinput DLL windows only for now
  lib, ok = DLIB.load_library("xinput1_4.dll")

  if !ok {
    lib, ok = DLIB.load_library("xinput1_3.dll")
    H.wMessageBox("13", "Handmade Hero")
  }

  if !ok {
    lib, ok = DLIB.load_library("xinput9_1_0.dll")
    H.wMessageBox("910", "Handmade Hero")
  }

  if ok {
    tmp := DLIB.symbol_address( lib, "XInputEnable")
    Enable := cast(proc(WIN32.BOOL))tmp

    tmp = DLIB.symbol_address( lib, "XInputGetAudioDeviceIds")
    GetAudioDeviceIds := cast(proc( WIN32.DWORD,  WIN32.LPWSTR, ^WIN32.UINT, 
                          WIN32.LPWSTR, ^WIN32.UINT) -> WIN32.DWORD)tmp

    tmp = DLIB.symbol_address( lib, "XInputGetBatteryInformation")
    GetBatteryInformation := cast(proc( WIN32.DWORD, WIN32.BYTE,
                             ^BATTERY_INFORMATION) -> WIN32.DWORD )tmp

    tmp = DLIB.symbol_address( lib, "XInputGetCapabilities")
    GetCapabilities := cast(proc( WIN32.DWORD,WIN32.DWORD, 
                                  ^CAPABILITIES) -> WIN32.DWORD )tmp

    tmp = DLIB.symbol_address( lib, "XInputGetDSoundAudioDeviceGuids")
    GetDSoundAudioDeviceGuids := cast(proc( WIN32.DWORD, ^WIN32.GUID, 
                                 ^WIN32.GUID) -> WIN32.DWORD )tmp

    tmp = DLIB.symbol_address( lib, "XInputGetKeystroke")
    GetKeystroke := cast(proc( WIN32.DWORD, WIN32.DWORD, 
                                ^KEYSTROKE) -> WIN32.DWORD )tmp

    tmp = DLIB.symbol_address( lib, "XInputGetState")
    GetState = cast( proc(WIN32.DWORD, ^STATE) -> WIN32.DWORD)tmp

    tmp = DLIB.symbol_address( lib, "XInputSetState")
    SetState = cast(proc( WIN32.DWORD, ^VIBRATION) -> WIN32.DWORD)tmp

  } else {
    GetState                  = GetStateNothing
    Enable                    = EnableNothing
    GetAudioDeviceIds         = GetAudioDeviceIdsNothing
    GetBatteryInformation     = GetBatteryInformationNothing
    GetCapabilities           = GetCapabilitiesNothing
    GetDSoundAudioDeviceGuids = GetDSoundAudioDeviceGuidsNothing
    GetKeystroke              = GetKeystokeNothing
    SetState                  = SetStateNothing
  }
}

//************************* STRUCTS ***************************//

GAMEPAD :: struct {
  wButtons:      WIN32.WORD
  bLeftTrigger:  WIN32.BYTE
  bRightTrigger: WIN32.BYTE
  sThumbLX:      WIN32.SHORT
  sThumbLY:      WIN32.SHORT
  sThumbRX:      WIN32.SHORT
  sThumbRY:      WIN32.SHORT
}

STATE :: struct {
    dwPacketNumber: WIN32.DWORD
    gamepad : GAMEPAD
}

KEYSTROKE :: struct {
  VirtualKey: WIN32.DWORD
  Unicode:    WIN32.DWORD
  Flags:      WIN32.DWORD
  UserIndex:  WIN32.BYTE
  HidCode:    WIN32.BYTE
} 


BATTERY_INFORMATION :: struct {
  BatteryType : WIN32.BYTE
  BatteryLevel: WIN32.BYTE
}

VIBRATION :: struct {
  wLeftMotorSpeed: WIN32.WORD
  wRightMotorSpeed: WIN32.WORD
}

CAPABILITIES :: struct {
  Type:      WIN32.BYTE
  SubType:   WIN32.BYTE
  Gamepad:   GAMEPAD
  Vibration: VIBRATION
}


//************************* constants ***************************//

// Gamepad Button Constants, wButtons
GAMEPAD_DPAD_UP        :: 0x0001
GAMEPAD_DPAD_DOWN      :: 0x0002
GAMEPAD_DPAD_LEFT      :: 0x0004
GAMEPAD_DPAD_RIGHT     :: 0x0008
GAMEPAD_START          :: 0x0010
GAMEPAD_BACK           :: 0x0020
GAMEPAD_LEFT_THUMB     :: 0x0040
GAMEPAD_RIGHT_THUMB    :: 0x0080
GAMEPAD_LEFT_SHOULDER  :: 0x0100
GAMEPAD_RIGHT_SHOULDER :: 0x0200
GAMEPAD_A              :: 0x1000
GAMEPAD_B              :: 0x2000
GAMEPAD_X              :: 0x4000
GAMEPAD_Y              :: 0x8000

// Returned constants for gamepad keystrokes
VK_PAD_A                 :: 0x5800
VK_PAD_B                 :: 0x5801
VK_PAD_C                 :: 0x5802
VK_PAD_D                 :: 0x5803  
VK_PAD_RSHOULDER         :: 0x5804
VK_PAD_LSHOULDER         :: 0x5805
VK_PAD_LTRIGGER          :: 0x5806
VK_PAD_RTRIGGER          :: 0x5807

VK_PAD_DPAD_UP           :: 0x5810
VK_PAD_DPAD_DOWN         :: 0x5811
VK_PAD_DPAD_LEFT         :: 0x5812
VK_PAD_DPAD_RIGHT        :: 0x5813  
VK_PAD_START             :: 0x5814
VK_PAD_BACK              :: 0x5815
VK_PAD_LTHUMB_PRESS      :: 0x5816
VK_PAD_RTHUMB_PRESS      :: 0x5817

VK_PAD_LTHUMB_UP         :: 0x5820
VK_PAD_LTHUMB_DOWN       :: 0x5821
VK_PAD_LTHUMB_LEFT       :: 0x5822
VK_PAD_LTHUMB_RIGHT      :: 0x5823  
VK_PAD_LTHUMB_UPLEFT     :: 0x5824
VK_PAD_LTHUMB_UPRIGHT    :: 0x5825
VK_PAD_LTHUMB_DOWNRIGHT  :: 0x5826
VK_PAD_LTHUMB_DOWNLEFT   :: 0x5827

VK_PAD_RTHUMB_UP         :: 0x5830
VK_PAD_RTHUMB_DOWN       :: 0x5831
VK_PAD_RTHUMB_LEFT       :: 0x5832
VK_PAD_RTHUMB_RIGHT      :: 0x5833  
VK_PAD_RTHUMB_UPLEFT     :: 0x5834
VK_PAD_RTHUMB_UPRIGHT    :: 0x5835
VK_PAD_RTHUMB_DOWNRIGHT  :: 0x5836
VK_PAD_RTHUMB_DOWNLEFT   :: 0x5837

// Constant to pass to XInputGetCapabilities
FLAG_GAMEPAD                 :: 0x1

// Types and subtypes Constance in CAPABILITIES
DEVSUBTYPE_UNKNOWN           :: 0x00
DEVSUBTYPE_GAMEPAD           :: 0x01 //LEGACY XINPUT ALWAYS RETURNS GAMEPAD
DEVSUBTYPE_WHEEL             :: 0x02
DEVSUBTYPE_ARCADE_STICK      :: 0x03
DEVSUBTYPE_FLIGHT_STICK      :: 0x04
DEVSUBTYPE_DANCE_PAD         :: 0x05
DEVSUBTYPE_GUITAR            :: 0x06
DEVSUBTYPE_GUITAR_ALTERNATE  :: 0x07
DEVSUBTYPE_DRUM_KIT          :: 0x08
DEVSUBTYPE_GUITAR_BASS       :: 0x0B
DEVSUBTYPE_ARCADE_PAD        :: 0x13

// Capabilitiy constants
CAPS_FFB_SUPPORTED           :: 0x01 
CAPS_WIRELESS                :: 0x02
CAPS_VOICE_SUPPORTED         :: 0x04
CAPS_PMD_SUPPORTED           :: 0x08
CAPS_NO_NAVIGATION           :: 0x10

// Limit Constants
GAMEPAD_LEFT_THUMB_DEADZONE  : WIN32.SHORT : 7849
GAMEPAD_RIGHT_THUMB_DEADZONE : WIN32.SHORT : 8689
GAMEPAD_TRIGGER_THRESHOLD    :: 30

// Index Constants
XUSER_MAX_COUNT                     :: 4
XUSER_INDEX_ANY                     :: 4

//Devices that support Batteries
BATTERY_DEVTYPE_GAMEPAD   :: 0x00
BATTERY_DEVTYPE_HEADSET   :: 0x01

//Battery Status
BATTERY_TYPE_DISCONNECTED :: 0x00
BATTERY_TYPE_WIRED        :: 0x01
BATTERY_TYPE_ALKALINE     :: 0x02
BATTERY_TYPE_NIMH         :: 0x03
BATTERY_TYPE_UNKOWN       :: 0xff

//Time remaining
//Only for valid, wireless, connected, and known battery devices
BATTERY_LEVEL_EMPTY       :: 0x0
BATTERY_LEVEL_LOW         :: 0x1
BATTERY_LEVEL_MEDIUM      :: 0x2
BATTERY_LEVEL_FULL        :: 0x3


// Constants that are returned by XInputGetKeystroke

KEYSTROKE_KEYDOWN :: 0x1
KEYSTROKE_KEYUP   :: 0x2
KEYSTROKE_REPEAT  :: 0x4


