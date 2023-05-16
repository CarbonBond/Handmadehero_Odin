package wasapi

import WIN32  "core:sys/windows"
import DXGI "vendor:directx/dxgi"
import H "../../helper"
import DLIB "core:dynlib"

@init
init :: proc() {
  lib : DLIB.Library
  ok  : bool
  //Load Xinput DLL windows only for now
  lib, ok = DLIB.load_library("Winmm.dll")
  if ok {
    tmp, found := DLIB.symbol_address(lib, "waveOutOpen")
    if found {
      H.MessageBox("lib loaded", "Handmade")
    }
  } else { 
    H.MessageBox("NOT loaded", "Handmade")
  }
}

/* NOTES
    
    Device endpoints refers to the hardware at the end of a data path.
    https://learn.microsoft.com/en-us/windows/win32/coreaudio/audio-endpoint-devices


*/

// ************* STRUCTS/CLASS ********************

/*  IMMDeviceEnumerator interface
*   https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nn-mmdeviceapi-immdeviceenumerator
*  
*   The device enumerator inherits from IUnknown
*   https://learn.microsoft.com/en-us/windows/win32/api/unknwn/nn-unknwn-iunknown
*/ 

IMMDeviceEnumerator :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IMMDeviceEnumerator
  //VTable 
}

// This contains the methods for IMMDeviceEnumerator and IUnknown
vtable_IMMDeviceEnumerator :: struct {
  using iunknown_vtale:   dxgi.IUknown_VTable

  // Generates a collection of audio endpoint devices that meet the 
  // specified criteria
  EnumAudioEndpoints:     proc "std" (
    this:          ^IMMDeviceEnumerator, 
    dataFlow:       EDataFlow, // Flow Direction (See EDataFlow in ENUM)
    dwStateMask:    WIN32.DWORD, // Selector (See Device State Constants)
    ppDevices:    ^^IMMDeviceCollection // Where endpoints get stored
  ) -> WIN32.HRESULT

  //Stores the default Endpoint for the flow direction and role. 
  // DATA -> ENDPOINT would return some listening device.
  GetDefaultAudioEndpoint: proc "std" (
    this:          ^IMMDeviceEnumerator,
    dataFlow:       EDataFlow, // Flow Direction (See EDataFlow in ENUM)
    role:           ERole,      // Role of device (See ERole in ENUM)
    ppEndpoint:   ^^IMMDevice  // Where the endpoint gets stored
  ) -> WIN32.HRESULT

  //Store Endpoint selected by an ID String.
  GetDevice: proc "std" (
    this:        ^IMMDeviceEnumerator,
    pwstrId,      WIN32.LPCWSTR, // points to a string containing EndpoinT ID
    ppDevice:   ^^IMMDevice      // Where the endpoint gets stored
  ) -> WIN32.HRESULT

  // Creates notification callback interface
  RegisterEndpointNotificationCallback proc "std" ( 
    pClient: ^IMMNotificationClient //Client registers for notification callback
  ) -> WIN32.HRESULT 

  // Deletes notification callback interface
  UnregisterEndpointNotificationCallback proc "std" (
    pClient: ^IMMNotificationClient //Client registers for notification callback
  ) -> WIN32.HRESULT 

}


//TODO (Carbon) Add IMMNotificationClient


// ************* ENUMS *******************

  EDataFlow : enum i32 {
  eRender = 0, // Rendering stream. Data flows from APP -> DEVICE.
  eCapture,    // Capture Stream. Data flows from DEVICE -> APP
  eAll,        // capture or render. Data flows both directions DEVICE <--> APP
  EDataFlow_enum_count // Count of this enum not including self.
}
/* The following methods use EDataFlow:
*  IMMDeviceEnumerator:   GetDefaultAudioEndpoint, EnumAudioEndpoints
*  IMMEndpoint:           GetDataFlow
*  IMMNotificationClient: OnDefaultDeviceChanged
*/

ERole : enum i32 {
  eConsole = 0,    // Games, System Notifactions sounds, and voice commands. 
  eMultimedia,     // Music, Movies, narration, live music recording 
  eCommunications, // Voice Communication (talking to another person)
  ERole_enum_count // Count of this enum not including self.
}
/* The following methods use EDataFlow:
*  IMMDeviceEnumerator:   GetDefaultAudioEndpoint 
*  IMMNotificationClient: OnDefaultDeviceChanged
*/

// ************* CONSTANTS *******************

// Device States Constatns (Can use logical OR)
// Can only open a Stream on DEVICE_STATE_ACTIVE endpoints.
DEVICE_STATE_ACTIVE     :: 0x01 // Device is actve 
DEVICE_STATE_DISABLED   :: 0x02 // Device is disabled in windows OS
DEVICE_STATE_NOTPRESENT :: 0x04 // Devcie is not present 
DEVICE_STATE_UNPLUGGED  :: 0x08 // device is unplugged, (Jack-presence detection)
DEVICE_STATEMASK_ALL    :: 0x0F // ALL devices
/* The following methods use :
*  IMMDeviceEnumerator:   GetAudioEndpoints
*  IMMDevice:             GetState
*  IMMNotificationClient: OnDeviceStateChanged
*/

