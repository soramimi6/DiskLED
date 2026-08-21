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
  public
    function Sample: Double;
  end;

implementation

uses
  Winapi.Windows;

function FileTimeToUInt64(const ATime: TFileTime): UInt64;
begin
  Result := (UInt64(ATime.dwHighDateTime) shl 32) or ATime.dwLowDateTime;
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
  TotalDelta: UInt64;
begin
  Result := FLast;
  if not GetSystemTimes(IdleTime, KernelTime, UserTime) then
    Exit;

  Idle := FileTimeToUInt64(IdleTime);
  Kernel := FileTimeToUInt64(KernelTime);
  User := FileTimeToUInt64(UserTime);

  if FHasPrev then
  begin
    IdleDelta := Idle - FPrevIdle;
    TotalDelta := (Kernel - FPrevKernel) + (User - FPrevUser);
    if TotalDelta > 0 then
    begin
      if IdleDelta > TotalDelta then
        IdleDelta := TotalDelta;
      Result := (1.0 - (IdleDelta / TotalDelta)) * 100.0;
      if Result < 0 then
        Result := 0;
      if Result > 100 then
        Result := 100;
      FLast := Result;
    end;
  end;

  FPrevIdle := Idle;
  FPrevKernel := Kernel;
  FPrevUser := User;
  FHasPrev := True;
end;

end.
