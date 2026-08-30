unit uCpuCollector;

interface

type
  TCpuCollector = class
  private
    FPrevIdle: UInt64;
    FPrevKernel: UInt64;
    FPrevUser: UInt64;
    FHasPrev: Boolean;
    FLast: Double;
    FUserPct: Double;
    FKernelPct: Double;
    FName: string;
    FCores: Integer;
    FThreads: Integer;
    FMaxMhz: Integer;
    FCurrentMhz: Integer;
    procedure LoadStatic;
    procedure SampleClock;
  public
    constructor Create;
    function Sample: Double;
    property UserPct: Double read FUserPct;
    property KernelPct: Double read FKernelPct;
    property Name: string read FName;
    property Cores: Integer read FCores;
    property Threads: Integer read FThreads;
    property MaxMhz: Integer read FMaxMhz;
    property CurrentMhz: Integer read FCurrentMhz;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

const
  RelProcessorCore = 0;
  PowerProcessorInformation = 11;

type
  TSysLogicalProcessorInformation = packed record
    ProcessorMask: ULONG_PTR;
    Relationship: DWORD;
    Pad: DWORD;
    Reserved: array[0..1] of UInt64;
  end;
  PSysLogicalProcessorInformation = ^TSysLogicalProcessorInformation;

  TProcessorPowerInformation = record
    Number: ULONG;
    MaxMhz: ULONG;
    CurrentMhz: ULONG;
    MhzLimit: ULONG;
    MaxIdleState: ULONG;
    CurrentIdleState: ULONG;
  end;
  PProcessorPowerInformation = ^TProcessorPowerInformation;

function GetLogicalProcessorInfo(Buffer: Pointer; var ReturnLength: DWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'GetLogicalProcessorInformation';
function NtPowerInformation(InformationLevel: Integer; InputBuffer: Pointer;
  InputBufferLength: ULONG; OutputBuffer: Pointer; OutputBufferLength: ULONG): DWORD; stdcall;
  external 'powrprof.dll' name 'CallNtPowerInformation';

function FileTimeToUInt64(const ATime: TFileTime): UInt64;
begin
  Result := (UInt64(ATime.dwHighDateTime) shl 32) or ATime.dwLowDateTime;
end;

function CollapseSpaces(const S: string): string;
var
  i: Integer;
begin
  Result := Trim(S);
  i := 1;
  while i < Length(Result) do
  begin
    if (Result[i] = ' ') and (Result[i + 1] = ' ') then
      Delete(Result, i + 1, 1)
    else
      Inc(i);
  end;
end;

constructor TCpuCollector.Create;
begin
  inherited Create;
  LoadStatic;
end;

procedure TCpuCollector.LoadStatic;
var
  Sys: TSystemInfo;
  K: HKEY;
  Buf: array[0..255] of Char;
  Sz, Typ, Mhz: DWORD;
  Need: DWORD;
  Raw: Pointer;
  Info: PSysLogicalProcessorInformation;
  Bytes, Step: Integer;
begin
  FName := '';
  FCores := 0;
  FThreads := 0;
  FMaxMhz := 0;
  GetSystemInfo(Sys);
  FThreads := Integer(Sys.dwNumberOfProcessors);
  if FThreads < 1 then
    FThreads := 1;

  Need := 0;
  GetLogicalProcessorInfo(nil, Need);
  if Need > 0 then
  begin
    GetMem(Raw, Need);
    try
      if GetLogicalProcessorInfo(Raw, Need) then
      begin
        Step := SizeOf(TSysLogicalProcessorInformation);
        if Step < 1 then
          Step := 1;
        Bytes := 0;
        while Bytes + Step <= Integer(Need) do
        begin
          Info := PSysLogicalProcessorInformation(NativeUInt(Raw) + NativeUInt(Bytes));
          if Info.Relationship = RelProcessorCore then
            Inc(FCores);
          Inc(Bytes, Step);
        end;
      end;
    finally
      FreeMem(Raw);
    end;
  end;
  if FCores < 1 then
    FCores := FThreads;

  if RegOpenKeyEx(HKEY_LOCAL_MACHINE,
    'HARDWARE\DESCRIPTION\System\CentralProcessor\0', 0, KEY_READ, K) = ERROR_SUCCESS then
  try
    Sz := SizeOf(Buf);
    FillChar(Buf, SizeOf(Buf), 0);
    if RegQueryValueEx(K, 'ProcessorNameString', nil, @Typ, @Buf[0], @Sz) = ERROR_SUCCESS then
      FName := CollapseSpaces(Buf);
    Sz := SizeOf(Mhz);
    if RegQueryValueEx(K, '~MHz', nil, @Typ, @Mhz, @Sz) = ERROR_SUCCESS then
      FMaxMhz := Integer(Mhz);
  finally
    RegCloseKey(K);
  end;
end;

procedure TCpuCollector.SampleClock;
var
  n, i, Sum, CurMax: Integer;
  Buf: Pointer;
  Info: PProcessorPowerInformation;
begin
  FCurrentMhz := FMaxMhz;
  n := FThreads;
  if n < 1 then
    Exit;
  GetMem(Buf, n * SizeOf(TProcessorPowerInformation));
  try
    FillChar(Buf^, n * SizeOf(TProcessorPowerInformation), 0);
    if NtPowerInformation(PowerProcessorInformation, nil, 0, Buf,
      n * SizeOf(TProcessorPowerInformation)) <> 0 then
      Exit;
    Sum := 0;
    CurMax := 0;
    for i := 0 to n - 1 do
    begin
      Info := PProcessorPowerInformation(NativeUInt(Buf) +
        NativeUInt(i) * SizeOf(TProcessorPowerInformation));
      Inc(Sum, Integer(Info.CurrentMhz));
      if Integer(Info.CurrentMhz) > CurMax then
        CurMax := Integer(Info.CurrentMhz);
      if (FMaxMhz < 1) and (Info.MaxMhz > 0) then
        FMaxMhz := Integer(Info.MaxMhz);
    end;
    if n > 0 then
      FCurrentMhz := Sum div n;
    if FCurrentMhz < 1 then
      FCurrentMhz := CurMax;
  finally
    FreeMem(Buf);
  end;
end;

function TCpuCollector.Sample: Double;
var
  IdleTime: TFileTime;
  KernelTime: TFileTime;
  UserTime: TFileTime;
  Idle: UInt64;
  Kernel: UInt64;
  User: UInt64;
  IdleDelta: UInt64;
  UserDelta: UInt64;
  KernelDelta: UInt64;
  PrivDelta: UInt64;
  TotalDelta: UInt64;
begin
  Result := FLast;
  SampleClock;
  if not GetSystemTimes(IdleTime, KernelTime, UserTime) then
    Exit;

  Idle := FileTimeToUInt64(IdleTime);
  Kernel := FileTimeToUInt64(KernelTime);
  User := FileTimeToUInt64(UserTime);

  if FHasPrev then
  begin
    IdleDelta := Idle - FPrevIdle;
    KernelDelta := Kernel - FPrevKernel;
    UserDelta := User - FPrevUser;
    TotalDelta := KernelDelta + UserDelta;
    if TotalDelta > 0 then
    begin
      if IdleDelta > TotalDelta then
        IdleDelta := TotalDelta;
      if KernelDelta >= IdleDelta then
        PrivDelta := KernelDelta - IdleDelta
      else
        PrivDelta := 0;
      Result := (1.0 - (IdleDelta / TotalDelta)) * 100.0;
      FUserPct := UserDelta / TotalDelta * 100.0;
      FKernelPct := PrivDelta / TotalDelta * 100.0;
      if Result < 0 then Result := 0;
      if Result > 100 then Result := 100;
      if FUserPct < 0 then FUserPct := 0;
      if FUserPct > 100 then FUserPct := 100;
      if FKernelPct < 0 then FKernelPct := 0;
      if FKernelPct > 100 then FKernelPct := 100;
      FLast := Result;
    end;
  end;

  FPrevIdle := Idle;
  FPrevKernel := Kernel;
  FPrevUser := User;
  FHasPrev := True;
end;

end.
