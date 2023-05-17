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
    tmp, found := DLIB.symbol_address(lib, "")
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
    this:        ^IMMDeviceEnumerator,
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
    this:          ^IMMNotificationClient
    dataFlow:       EDataFlow, // Flow Direction (See EDataFlow in ENUM)
    role:           ERole,      // Role of device (See ERole in ENUM)
    ppEndpoint:   ^^IMMDevice  // Where the endpoint gets stored
  ) -> WIN32.HRESULT,

  //Store Endpoint selected by an ID String.
  GetDevice: proc "std" (
    this:          ^IMMNotificationClient
    pwstrId,      WIN32.LPCWSTR, // points to a string containing EndpoinT ID
    ppDevice:   ^^IMMDevice      // Where the endpoint gets stored
  ) -> WIN32.HRESULT,

  // Creates notification callback interface
  RegisterEndpointNotificationCallback proc "std" ( 
    this:          ^IMMNotificationClient
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
  using iunknown_vtable:   dxgi.IUnknown_VTable,

  // Creates a COM object with the specified interface
  Activate: proc "std" (
    this:               ^IMMDevice
    iid:                 WIN32.REFIID, // reference to a GUID
    dwClsCts:            WIN32.DWORD,  // Context restriction (CLSCTX enum)
    pActivationParams:  ^PROPVARIANT,  // for type of interface (IAudio = NULL)
    ppInterface:       ^^rawptr //TODO(Carbon) is a double rawptr the best?
  ) -> WIN32.HRESULT,

  // retrieves an interface to the device's property store.
  OpenPropertyStore: proc "std" (
    this:      ^IMMDevice
    stgmAccess: WIN32.DWORD // Storage Access mode for read, write, or r/w mode.
    ppProperties: ^^IPropertyStore // Writes address of IPropertyStore interface.
  ) -> WIN32.HRESULT,

  // Retrieves an endpoint ID string that identifites the Enpoint device
  GetId: proc "std" (
    this:    ^IMMDevice
    ppstrId: ^WIN32.LPWSTR, // ptr to ptr var which this writes the str into.
  ) -> WIN32.HRESULT,

  // Retrieves the current device state.
  GetState: proc "std" (
    this:     ^IMMDevice
    pdwState: ^WIN32.DWORD // Sets variable to the current state (See DEVICE STATE constants)
  ) -> WIN32.HRESULT,

}

IMMDeviceCollection :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IMMDeviceCollection 
  //VTable 
}

vtable_IMMDeviceCollection :: struct {
  using iunknown_vtable:   dxgi.IUnknown_VTable,

  //Retrieveces a count of the devices in the device collection
  GetCount : proc "std" (
    this:      ^IMMDeviceCollection
    pcDevices: ^WIN32.UINT // writes number of devices in the device collection
  ) -> WIN32.HRESULT   

  //Retrieves a pointer to a specivied item in device collection.
  Item : proc "std" (
    this:      ^IMMDeviceCollection
    nDevice: WIN32.UINT // Device Number
    ppDevice: ^^IMMDevice // writes the IMMDevice interface 
  ) -> WIN32.HRESULT  
}

IPropertyStore :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IPropertyStore
  //VTable 
}

vtable_IPropertyStore  :: struct {
  using iunknown_vtable:   dxgi.IUknown_VTable,

  // Gets the number of peoperties attached to the file
  GetCount : proc "std" (
    this:   ^IPropertyStore
    cProps: ^WIN32.DWORD // ptr to a value that indicates the property count.
  ) -> WIN32.HRESULT,

  // Get property key from the property array of an item
  GetAt : proc "std" (
    this:   ^IPropertyStore
    iProp :  WIN32.DWORD, // index into array of PROPERTYKEY structs  
    pkey:   ^PROPERTYKEY, // TDB (Litterally what is says in the docs lol)
  ) -> WIN32.HRESULT,

  // Gets data for a specific property
  GetValue : proc "std" (
    this:   ^IPropertyStore
    key: REFPROPERTYKEY // TBD (Again? really windows...)
    pv: ^PROPVARIANT // after GetValue returns, this points to a PROPVARIANT struct
  ) -> WIN32.HRESULT,

  // Sets property value, replaces, or removes an existing value
  SetValue : proc "std" (
    this:   ^IPropertyStore
    key: REFPROPERTYKEY // TBD (Three)
    propvar: ^PROPVARIANT // TBD ( and Four "TBD"s. Well played windows)
  ) -> WIN32.HRESULT,

  // Save the changes after they have been made.
  Commit : proc "std" (this:   ^IPropertyStore) -> WIN32.HRESULT,

}


IMMNotificationClient :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IMMNotificationClient
  //VTable 
}

vtable_IMMNotificationClient  :: struct {
  using iunknown_vtable:   dxgi.IUknown_VTable

  // Notifies client that default Endpoint device for a device role has changed.
  OnDefaultDeviceChanged: proc "std" (
    this:            ^IMMNotificationClient
    flow:             EDataFlow,    // Flow Direction (See EDataFlow in ENUM)
    role:             ERole  ,      // Role of device (See ERole in ENUM)
    pwstrDefaultDeviceID: WIN32.LPCWSTR // Endpoint identifier string
  ) -> WIN32.HRESULT 

  // Indicates new Endpoint device has been added
  OnDeviceAdded: proc "std" (
    this:         ^IMMNotificationClient
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
  ) -> WIN32.HRESULT

  // Indicates Endpoint device has been removed.
  OnDeviceRemoved: proc "std" (
    this:         ^IMMNotificationClient
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
  ) -> WIN32.HRESULT

  // Indicates Endpoint device state has changed
  OnDeviceStateChanged: proc "std" (
    this:         ^IMMNotificationClient
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
    dwNewState:    WIN32.DWORD   // Takes a new state (See DEVICE STATE CONSTANTS)
  ) -> WIN32.HRESULT

  // Indicated a property has changed for an Endpoint Device
  OnPropertValueChanged: proc "std" (
    this:         ^IMMNotificationClient
    pwstrDeviceId: WIN32.LPCWSTR // Endpoint identifier string
    key:           PROPERTYKEY   // Specifires property GUID and index
  ) -> WIN32.HRESULT
}

IAudioClient :: struct {
  #subtype iunknown: DXGI.IUnknown
  using vtable: ^vtable_IAudioClient
  //VTable 
}

vtable_IAudioClient :: struct {
  using iunknown_vtable:   dxgi.IUnknown_VTable,

  //Initializes audio stream
  Initialize: proc "std" (
    this:             ^IAudioClient,
    ShareMode:          AUDCLNT_SHAREMODE, //Share with other devices (ENUM)
    StreamFlags:       WIN32.DWORD,      // Controls creation of stream. 
    hnsBufferDuration: REFERENCE_TIME,   // buffer cap as time value. 100nano
    hnsPeriodicity:    REFERENCE_TIME,   // Device period. != 0 in exclusive
    pFormat:           ^WAVEFORMATEX,    // format descriptor see WAVEFORMATEX
    AudioSessionGuid:  WIN32.LPCGUID     // Audio Session GUID
  ) -> WIN32.HRESULT

  //Retrieves the max capacity of the endpoint buffer
  GetBufferSize: proc "std" (
    this: ^IAudioClient,
    pNumBufferFrames: ^WIN32.UINT32 // writes number of audio frames buffer can hold
  ) -> WIN32.HRESULT

  // retrieves the max latency for current steam
  GetStreamLatency: proc "std" (
    this: ^IAudioClient,
    phnsLatency: ^REFERENCE_TIME // writes the time in 100-nanosecond units
  ) -> WIN32.HRESULT

  // retrieves the number of frames of padding in endpoint buffer
  GetCurrentPadding: proc "std" (
    this: ^IAudioClient,
    pNumPaddingFrames: ^WIN32.UINT32 // writes the frame count
  ) -> WIN32.HRESULT

  // indicated whether endpoint device supports a stream format
  IsFormatSupported: proc "std" (
    this: ^IAudioClient,
    ShareMode: AUDCLNT_SHAREMODE,  // exclusive or shared mode
    pFormat: ^WAVEFORMATEX         // specified formate 
    ppClosestMatch: ^^WAVEFORMATEX // Write closest format to pFormat
  ) -> WIN32.HRESULT

  // retrieves stream format that audio engine uses for internal processing.
  GetMixFormat: proc "std" (
    this: ^IAudioClient,
    ppDeviceFormat: ^^WAVEFORMATEX // writes address of mix formate
  ) -> WIN32.HRESULT

  // Retrieves the length of the periodic interval for processing pases
  GetDevicePeriod: proc "std" (
    this: ^IAudioClient,
    phnsDefaultDevicePeriod: ^REFERENCE_TIME //Writes default interval between processing passes
    phnsMinimumDevicePeriod: ^REFERENCE_TIME //Writes minimum interval between processing passes
  ) -> WIN32.HRESULT

  // Start the audio stream
  Start: proc "std" ( this: ^IAudioClient) -> WIN32.HRESULT
  // Stop the audio stream
  Stop:  proc "std" ( this: ^IAudioClient) -> WIN32.HRESULT
  // resets audio stream
  Reset: proc "std" ( this: ^IAudioClient,) -> WIN32.HRESULT
  
  // Sets event handle that the system signals when buffer is ready.
  SetEventHandle: proc "std" (
    this: ^IAudioClient,
    eventHandle: WIN32.HANDLE
  ) -> WIN32.HRESULT

  // accesses additional services from audio client
  GetService: proc "std" (
    this: ^IAudioClient,
    riid: REFIID // Interface ID for requested service
    ppv: ^^rawptr // writes address of an instance of request interface.
  ) -> WIN32.HRESULT

}


// ************* TYPES/STRUCTS ********************

PROPERTYKEY : struct {
  fmtid: DXGI.GUID
  pid:   WIN32.DWORD
}

PROPVARIANT ::  distinct rawptr //TODO(Carbon) Should I fully implement this?

WAVEFORMATEX {
  wFormatTag:      WIN32.WORD
  nChannels:       WIN32.WORD
  nSamplesPerSec:  WIN32.DWORD
  nAvgBytesPerSec: WIN32.DWORD
  nBlockAlign:     WIN32.WORD
  wBitsPerSample:  WIN32.WORD
  cbSize:          WIN32.WORD
}

REFERENCE_TIME :: i64

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

AUDCLNT_SHAREMODE : enum i32 {
  AUDCLNT_SHAREMODE_SHARED,
  AUDCLNT_SHAREMODE_EXCLUSIVE
}
/* The following methods use AUDCLNT_SHAREMODE:
*  IAudioClient:  Initialize IsFormatSupported 
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

AUDCLNT_STREAMFLAGS_CROSSPROCESS        :: 0x00010000
AUDCLNT_STREAMFLAGS_LOOPBACK            :: 0x00020000
AUDCLNT_STREAMFLAGS_EVENTCALLBACK       :: 0x00040000
AUDCLNT_STREAMFLAGS_NOPERSIST           :: 0x00080000
AUDCLNT_STREAMFLAGS_RATEADJUST          :: 0x00100000
AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM      :: 0x80000000
AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY :: 0x08000000

AUDCLNT_SESSIONFLAGS_EXPIREWHENUNOWNED       :: 0x10000000
AUDCLNT_SESSIONFLAGS_DISPLAY_HIDE            :: 0x20000000
AUDCLNT_SESSIONFLAGS_DISPLAY_HIDEWHENEXPIRED :: 0x40000000 


// Below was supplied by fendevel as I don't know enough about UUID stuff 
// Src: https://github.com/fendevel/odin-wasapi/blob/main/wasapi.odin

CLSCTX_ALL :: windows.CLSCTX_INPROC_SERVER | windows.CLSCTX_INPROC_HANDLER | windows.CLSCTX_LOCAL_SERVER | windows.CLSCTX_REMOTE_SERVER
CLSID_MMDeviceEnumerator := IAudioClient_UUID_STRING :: "1CB9AD4C-DBFA-4c32-B178-C2F568A703B2"

IAudioClient_UUID_STRING :: "1CB9AD4C-DBFA-4c32-B178-C2F568A703B2"
IAudioClient_UUID := &dxgi.IID{0x1CB9AD4C, 0xDBFA, 0x4c32, {0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2}}windows.GUID{0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}}
