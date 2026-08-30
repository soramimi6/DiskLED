unit uMemCollector;

interface

type
  TMemCollector = class
  public
    procedure Sample(out AMemUsage, ASwapUsage: Double;
      out AMemUsed, AMemTotal, AMemAvail, AMemCache,
      ASwapUsed, ASwapTotal, ACommit, ACommitLimit: UInt64);
  end;

implementation

uses
  Winapi.Windows;

type
  TWinPerfInfo = record
    cb: DWORD;
    CommitTotal: NativeUInt;
    CommitLimit: NativeUInt;
    CommitPeak: NativeUInt;
    PhysicalTotal: NativeUInt;
    PhysicalAvailable: NativeUInt;
    SystemCache: NativeUInt;
    KernelTotal: NativeUInt;
    KernelPaged: NativeUInt;
    KernelNonpaged: NativeUInt;
    PageSize: NativeUInt;
    HandleCount: DWORD;
    ProcessCount: DWORD;
    ThreadCount: DWORD;
  end;

function GetWinPerfInfo(var PerfInfo: TWinPerfInfo; cb: DWORD): BOOL; stdcall;
  external 'psapi.dll' name 'GetPerformanceInfo';

procedure TMemCollector.Sample(out AMemUsage, ASwapUsage: Double;
  out AMemUsed, AMemTotal, AMemAvail, AMemCache,
  ASwapUsed, ASwapTotal, ACommit, ACommitLimit: UInt64);
var
  Status: TMemoryStatusEx;
  Perf: TWinPerfInfo;
  Page: UInt64;
begin
  AMemUsage := 0;
  ASwapUsage := 0;
  AMemUsed := 0;
  AMemTotal := 0;
  AMemAvail := 0;
  AMemCache := 0;
  ASwapUsed := 0;
  ASwapTotal := 0;
  ACommit := 0;
  ACommitLimit := 0;
  FillChar(Status, SizeOf(Status), 0);
  Status.dwLength := SizeOf(Status);
  if not GlobalMemoryStatusEx(Status) then
    Exit;

  AMemTotal := Status.ullTotalPhys;
  AMemAvail := Status.ullAvailPhys;
  if Status.ullTotalPhys > Status.ullAvailPhys then
    AMemUsed := Status.ullTotalPhys - Status.ullAvailPhys
  else
    AMemUsed := 0;
  if Status.ullTotalPhys > 0 then
    AMemUsage := AMemUsed / Status.ullTotalPhys * 100.0;

  ASwapTotal := Status.ullTotalPageFile;
  if Status.ullTotalPageFile > Status.ullAvailPageFile then
    ASwapUsed := Status.ullTotalPageFile - Status.ullAvailPageFile
  else
    ASwapUsed := 0;
  if Status.ullTotalPageFile > 0 then
    ASwapUsage := ASwapUsed / Status.ullTotalPageFile * 100.0;

  FillChar(Perf, SizeOf(Perf), 0);
  Perf.cb := SizeOf(Perf);
  if GetWinPerfInfo(Perf, SizeOf(Perf)) and (Perf.PageSize > 0) then
  begin
    Page := UInt64(Perf.PageSize);
    AMemCache := UInt64(Perf.SystemCache) * Page;
    ACommit := UInt64(Perf.CommitTotal) * Page;
    ACommitLimit := UInt64(Perf.CommitLimit) * Page;
  end;

  if AMemUsage < 0 then
    AMemUsage := 0;
  if AMemUsage > 100 then
    AMemUsage := 100;
  if ASwapUsage < 0 then
    ASwapUsage := 0;
  if ASwapUsage > 100 then
    ASwapUsage := 100;
end;

end.
