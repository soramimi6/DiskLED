unit uAudioCollector;

{ Default render endpoint peaks via IAudioMeterInformation. No PCM / loopback.
  L/R are channels 0/1; Mono is max of all metering channels. }

interface

type
  TAudioCollector = class
  private
    FEnum: IUnknown;
    FMeter: IUnknown;
    FDeviceId: string;
    FDeviceName: string;
    FLastBindTick: Cardinal;
    FHasBindTick: Boolean;
    procedure ReleaseMeter;
    procedure BindDefault;
    function Enumerator: IUnknown;
    function MeterPeaks(out ALeft, ARight, AMono: Double): Boolean;
    procedure EnsureMeter;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Sample(out ALeft, ARight, AMono: Double; out ADeviceName: string);
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.ActiveX,
  uMetricsTypes;

const
  CRebindMs = 2000;
  CMaxMeterCh = 32;
  eRender = 0;
  eConsole = 0;

  CLSID_MMDeviceEnumerator: TGUID = '{BCDE0395-E52F-467C-8E3D-C4579291692E}';
  IID_IMMDeviceEnumerator: TGUID = '{A95664D2-9614-4F35-A746-DE8DB63617E6}';
  IID_IAudioMeterInformation: TGUID = '{C02216F6-8C67-4B5B-9D00-D008E73E0064}';

type
  TPropertyKey = packed record
    fmtid: TGUID;
    pid: DWORD;
  end;

  IPropertyStore = interface(IUnknown)
    ['{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}']
    function GetCount(out cProps: DWORD): HResult; stdcall;
    function GetAt(iProp: DWORD; out pkey: TPropertyKey): HResult; stdcall;
    function GetValue(const key: TPropertyKey; out pv: TPropVariant): HResult; stdcall;
    function SetValue(const key: TPropertyKey; const propvar: TPropVariant): HResult; stdcall;
    function Commit: HResult; stdcall;
  end;

const
  PKEY_Device_FriendlyName: TPropertyKey = (
    fmtid: (D1: $A45C254E; D2: $DF1C; D3: $4EFD;
      D4: ($80, $20, $67, $D1, $46, $A8, $50, $E0));
    pid: 14);

type
  IAudioMeterInformation = interface(IUnknown)
    ['{C02216F6-8C67-4B5B-9D00-D008E73E0064}']
    function GetPeakValue(out pfPeak: Single): HResult; stdcall;
    function GetMeteringChannelCount(out pnChannelCount: UINT): HResult; stdcall;
    function GetChannelsPeakValues(u32ChannelCount: UINT;
      afPeakValues: PSingle): HResult; stdcall;
    function QueryHardwareSupport(out pdwHardwareSupportMask: DWORD): HResult; stdcall;
  end;

  IMMDevice = interface(IUnknown)
    ['{D666063F-1587-4E43-81F1-B948E807363F}']
    function Activate(const iid: TGUID; dwClsCtx: DWORD; pActivationParams: Pointer;
      out ppInterface: IUnknown): HResult; stdcall;
    function OpenPropertyStore(stgmAccess: DWORD;
      out ppProperties: IUnknown): HResult; stdcall;
    function GetId(out ppstrId: PWideChar): HResult; stdcall;
    function GetState(out pdwState: DWORD): HResult; stdcall;
  end;

  IMMDeviceEnumerator = interface(IUnknown)
    ['{A95664D2-9614-4F35-A746-DE8DB63617E6}']
    function EnumAudioEndpoints(dataFlow: DWORD; dwStateMask: DWORD;
      out ppDevices: IUnknown): HResult; stdcall;
    function GetDefaultAudioEndpoint(dataFlow: DWORD; role: DWORD;
      out ppEndpoint: IMMDevice): HResult; stdcall;
    function GetDevice(pwstrId: PWideChar; out ppDevice: IMMDevice): HResult; stdcall;
    function RegisterEndpointNotificationCallback(pClient: IUnknown): HResult; stdcall;
    function UnregisterEndpointNotificationCallback(pClient: IUnknown): HResult; stdcall;
  end;

function DeviceIdOf(const ADev: IMMDevice): string;
var
  P: PWideChar;
begin
  Result := '';
  if ADev = nil then
    Exit;
  if ADev.GetId(P) <> S_OK then
    Exit;
  try
    Result := string(P);
  finally
    CoTaskMemFree(P);
  end;
end;

function FriendlyNameOf(const ADev: IMMDevice): string;
var
  Unk: IUnknown;
  Store: IPropertyStore;
  Pv: TPropVariant;
begin
  Result := '';
  if ADev = nil then
    Exit;
  if ADev.OpenPropertyStore(STGM_READ, Unk) <> S_OK then
    Exit;
  if not Supports(Unk, IPropertyStore, Store) then
    Exit;
  FillChar(Pv, SizeOf(Pv), 0);
  try
    if Store.GetValue(PKEY_Device_FriendlyName, Pv) <> S_OK then
      Exit;
    if (Pv.vt = VT_LPWSTR) and (Pv.pwszVal <> nil) then
      Result := Trim(string(Pv.pwszVal));
  finally
    PropVariantClear(Pv);
  end;
end;

constructor TAudioCollector.Create;
begin
  inherited Create;
  FEnum := nil;
  FMeter := nil;
  FDeviceId := '';
  FDeviceName := '';
  FHasBindTick := False;
end;

destructor TAudioCollector.Destroy;
begin
  ReleaseMeter;
  FEnum := nil;
  inherited;
end;

function TAudioCollector.Enumerator: IUnknown;
var
  Unk: IUnknown;
begin
  if FEnum <> nil then
    Exit(FEnum);
  if CoCreateInstance(CLSID_MMDeviceEnumerator, nil, CLSCTX_INPROC_SERVER,
    IID_IMMDeviceEnumerator, Unk) = S_OK then
    FEnum := Unk;
  Result := FEnum;
end;

procedure TAudioCollector.ReleaseMeter;
begin
  FMeter := nil;
  FDeviceId := '';
  FDeviceName := '';
end;

procedure TAudioCollector.BindDefault;
var
  Enum: IMMDeviceEnumerator;
  Dev: IMMDevice;
  Unk: IUnknown;
  Meter: IAudioMeterInformation;
  Id: string;
begin
  ReleaseMeter;
  if not Supports(Enumerator, IMMDeviceEnumerator, Enum) then
    Exit;
  if Enum.GetDefaultAudioEndpoint(eRender, eConsole, Dev) <> S_OK then
    Exit;
  Id := DeviceIdOf(Dev);
  if Dev.Activate(IID_IAudioMeterInformation, CLSCTX_ALL, nil, Unk) <> S_OK then
    Exit;
  if not Supports(Unk, IAudioMeterInformation, Meter) then
    Exit;
  FMeter := Meter;
  FDeviceId := Id;
  FDeviceName := FriendlyNameOf(Dev);
end;

procedure TAudioCollector.EnsureMeter;
var
  NowTick: Cardinal;
  Enum: IMMDeviceEnumerator;
  Dev: IMMDevice;
  Id: string;
begin
  NowTick := GetTickCount;
  if (not FHasBindTick) or ((NowTick - FLastBindTick) >= CRebindMs) then
  begin
    FLastBindTick := NowTick;
    FHasBindTick := True;
    if Supports(Enumerator, IMMDeviceEnumerator, Enum) then
    begin
      if Enum.GetDefaultAudioEndpoint(eRender, eConsole, Dev) = S_OK then
      begin
        Id := DeviceIdOf(Dev);
        if (FMeter = nil) or (Id <> FDeviceId) then
          BindDefault;
      end
      else
        ReleaseMeter;
    end;
  end;
  if FMeter = nil then
    BindDefault;
end;

function TAudioCollector.MeterPeaks(out ALeft, ARight, AMono: Double): Boolean;
var
  Meter: IAudioMeterInformation;
  Count: UINT;
  N, i: Integer;
  Peaks: array[0..CMaxMeterCh - 1] of Single;
  Peak: Single;
  Mono: Double;
begin
  ALeft := 0;
  ARight := 0;
  AMono := 0;
  Result := False;
  if not Supports(FMeter, IAudioMeterInformation, Meter) then
    Exit;
  if (Meter.GetMeteringChannelCount(Count) = S_OK) and (Count >= 1) then
  begin
    N := Integer(Count);
    if N > CMaxMeterCh then
      N := CMaxMeterCh;
    FillChar(Peaks, SizeOf(Peaks), 0);
    if Meter.GetChannelsPeakValues(UINT(N), @Peaks[0]) = S_OK then
    begin
      ALeft := Clamp01(Peaks[0]);
      if N >= 2 then
        ARight := Clamp01(Peaks[1]);
      Mono := 0;
      for i := 0 to N - 1 do
        if Peaks[i] > Mono then
          Mono := Peaks[i];
      AMono := Clamp01(Mono);
      Result := True;
      Exit;
    end;
  end;
  if Meter.GetPeakValue(Peak) <> S_OK then
    Exit;
  AMono := Clamp01(Peak);
  ALeft := AMono;
  ARight := AMono;
  Result := True;
end;

procedure TAudioCollector.Sample(out ALeft, ARight, AMono: Double;
  out ADeviceName: string);
begin
  ALeft := 0;
  ARight := 0;
  AMono := 0;
  ADeviceName := '';
  EnsureMeter;
  ADeviceName := FDeviceName;
  if MeterPeaks(ALeft, ARight, AMono) then
    Exit;
  ReleaseMeter;
  BindDefault;
  ADeviceName := FDeviceName;
  if not MeterPeaks(ALeft, ARight, AMono) then
  begin
    ALeft := 0;
    ARight := 0;
    AMono := 0;
  end;
end;

end.
