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


// ************* CLASSES ********************
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
  using iunknown_vtalbe:   dxgi.IUnknown_VTable,

  // Generates a collection of audio endpoint devices that meet the 
  // specified criteria
  EnumAudioEndpoints:     proc "std" (
    this:          ^IMMDeviceEnumerator, 
    dataFlow:       EDataFlow, // Flow Direction (See EDataFlow in ENUM)
    dwStateMask:    WIN32.DWORD, // Selector (See Device State Constants)
    ppDevices:    ^^IMMDeviceCollection // Where endpoints get stored
  ) -> WIN32.HRESULT,

  //Stores the default Endpoint for the flow direction and role. 
  // DATA -> ENDPOINT would return some listening device.
  GetDefaultAudioEndpoint: proc "std" (
    this:          ^IMMDeviceEnumerator,
    dataFlow:       EDataFlow, // Flow Direction (See EDataFlow in ENUM)
    role:           ERole,      // Role of device (See ERole in ENUM)
    ppEndpoint:   ^^IMMDevice  // Where the endpoint gets stored
  ) -> WIN32.HRESULT,

  //Store Endpoint selected by an ID String.
  GetDevice: proc "std" (
    this:        ^IMMDeviceEnumerator,
    pwstrId,      WIN32.LPCWSTR, // points to a string containing EndpoinT ID
    ppDevice:   ^^IMMDevice      // Where the endpoint gets stored
  ) -> WIN32.HRESULT,

  // Creates notification callback interface
  RegisterEndpointNotificationCallback proc "std" ( 
    pClient: ^IMMNotificationClient //Client registers for notification callback
  ) -> WIN32.HRESULT ,

  // Deletes notification callback interface
  UnregisterEndpointNotificationCallback proc "std" (
    pClient: ^IMMNotificationClient //Client registers for notification callback
  ) -> WIN32.HRESULT, 

}


IMMNotificationClient :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IMMNotificationClient
  //VTable 
}

vtable_IMMNotificationClient  :: struct {
  using iunknown_vtable:   dxgi.IUnknown_VTable,

  // Notifies client that default Endpoint device for a device role has changed.
  OnDefaultDeviceChanged: proc "std" (
    dataFlow:       EDataFlow, // Flow Direction (See EDataFlow in ENUM)
    role:           ERole,      // Role of device (See ERole in ENUM)
    ppEndpoint:   ^^IMMDevice  // Where the endpoint gets stored
  ) -> WIN32.HRESULT,

  //Store Endpoint selected by an ID String.
  GetDevice: proc "std" (
    this:        ^IMMDeviceEnumerator,
    pwstrId,      WIN32.LPCWSTR, // points to a string containing EndpoinT ID
    ppDevice:   ^^IMMDevice      // Where the endpoint gets stored
  ) -> WIN32.HRESULT,

  // Creates notification callback interface
  RegisterEndpointNotificationCallback proc "std" ( 
    pClient: ^IMMNotificationClient //Client registers for notification callback
  ) -> WIN32.HRESULT,

  // Deletes notification callback interface
  UnregisterEndpointNotificationCallback proc "std" (
    pClient: ^IMMNotificationClient //Client registers for notification callback
  ) -> WIN32.HRESULT,

}


IMMDevice  :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IMMDevice 
  //VTable 
}

vtable_IMMDevice   :: struct {
  using iunknown_vtable:   dxgi.IUnknown_VTable

  // Creates a COM object with the specified interface
  Activate: proc "std" (
    iid:                 WIN32.REFIID, // reference to a GUID
    dwClsCts:            WIN32.DWORD,  // Context restriction (CLSCTX enum)
    pActivationParams:  ^PROPVARIANT,  // for type of interface (IAudio = NULL)
    ppInterface:       ^^rawptr //TODO(Carbon) is a double rawptr the best?
  ) -> WIN32.HRESULT,

  // Retrieves an endpoint ID string that identifites the Enpoint device
  GetId: proc "std" (
    ppstrId: ^WIN32.LPWSTR, // ptr to ptr var which this writes the str into.
  ) -> WIN32.HRESULT,

  // Retrieves the current device state.
  GetState: proc "std" (
    pdwState: ^WIN32.DWORD // Sets variable to the current state (See DEVICE STATE constants)
  ) -> WIN32.HRESULT,

  // retrieves an interface to the device's property store.
  OpenPropertyStore: proc "std" (
    stgmAccess: WIN32.DWORD // Storage Access mode for read, write, or r/w mode.
    ppProperties: ^^IPropertyStore // Writes address of IPropertStore interface.
  ) -> WIN32.HRESULT,

}

//TODO(Carbon) IMMDeviceCollection 
//TODO(Carbon) IPropertyStore


IMMNotificationClient :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IMMNotificationClient
  //VTable 
}

vtable_IMMNotificationClient  :: struct {
  using iunknown_vtable:   dxgi.IUknown_VTable

  // Notifies client that default Endpoint device for a device role has changed.
  OnDefaultDeviceChanged: proc "std" (
    flow:             EDataFlow,    // Flow Direction (See EDataFlow in ENUM)
    role:                 ERole  ,      // Role of device (See ERole in ENUM)
    pwstrDefaultDeviceID: WIN32.LPCWSTR // Endpoint identifier string
  ) -> WIN32.HRESULT 

  // Indicates new Endpoint device has been added
  OnDeviceAdded: proc "std" (
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
  ) -> WIN32.HRESULT

  // Indicates Endpoint device has been removed.
  OnDeviceRemoved: proc "std" (
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
  ) -> WIN32.HRESULT

  // Indicates Endpoint device state has changed
  OnDeviceStateChanged: proc "std" (
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
    dwNewState:    WIN32.DWORD   // Takes a new state (See DEVICE STATE CONSTANTS)
  ) -> WIN32.HRESULT

  // Indicated a property has changed for an Endpoint Device
  OnPropertValueChanged: proc "std" (
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
    key:           PROPERTYKEY   // Specifires property GUID and index
  ) -> WIN32.HRESULT
}


// ************* STRUCTS ********************

PROPERTYKEY : struct {
  fmtid: DXGI.GUID
  pid:   WIN32.DWORD
}

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

/* CLSCTX Reference (in WIN32 library)
CLSCTX_INPROC_SERVER = 0x1,
CLSCTX_INPROC_HANDLER = 0x2,
CLSCTX_LOCAL_SERVER = 0x4,
CLSCTX_INPROC_SERVER16 = 0x8,
CLSCTX_REMOTE_SERVER = 0x10,
CLSCTX_INPROC_HANDLER16 = 0x20,
CLSCTX_RESERVED1 = 0x40,
CLSCTX_RESERVED2 = 0x80,
CLSCTX_RESERVED3 = 0x100,
CLSCTX_RESERVED4 = 0x200,
CLSCTX_NO_CODE_DOWNLOAD = 0x400,
CLSCTX_RESERVED5 = 0x800,
CLSCTX_NO_CUSTOM_MARSHAL = 0x1000,
CLSCTX_ENABLE_CODE_DOWNLOAD = 0x2000,
CLSCTX_NO_FAILURE_LOG = 0x4000,
CLSCTX_DISABLE_AAA = 0x8000,
CLSCTX_ENABLE_AAA = 0x10000,
CLSCTX_FROM_DEFAULT_CONTEXT = 0x20000,
CLSCTX_ACTIVATE_X86_SERVER = 0x40000,
CLSCTX_ACTIVATE_32_BIT_SERVER,
CLSCTX_ACTIVATE_64_BIT_SERVER = 0x80000,
CLSCTX_ENABLE_CLOAKING = 0x100000,
CLSCTX_APPCONTAINER = 0x400000,
CLSCTX_ACTIVATE_AAA_AS_IU = 0x800000,
CLSCTX_RESERVED6 = 0x1000000,
CLSCTX_ACTIVATE_ARM32_SERVER = 0x2000000,
CLSCTX_ALLOW_LOWER_TRUST_REGISTRATION,
CLSCTX_PS_DLL = 0x80000000
*/ 

CLSCTX_STD :: WIN32.CLSCTX_INPROC_SERVER | WIN32.CLSCTX_INPROC_HANDLER | 
              WIN32.CLSCTX_LOCAL_SERVER  | WIN32.CLSCTX_REMOTE_SERVER

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

