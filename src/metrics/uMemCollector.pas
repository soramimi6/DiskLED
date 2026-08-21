unit uMemCollector;

interface

type
  TMemCollector = class
  public
    procedure Sample(out AMemUsage, ASwapUsage: Double);
  end;

implementation

uses
  Winapi.Windows;

procedure TMemCollector.Sample(out AMemUsage, ASwapUsage: Double);
var
  Status: TMemoryStatusEx;
  Used: UInt64;
begin
  AMemUsage := 0;
  ASwapUsage := 0;
  FillChar(Status, SizeOf(Status), 0);
  Status.dwLength := SizeOf(Status);
  if not GlobalMemoryStatusEx(Status) then
    Exit;

  if Status.ullTotalPhys > 0 then
  begin
    Used := Status.ullTotalPhys - Status.ullAvailPhys;
    AMemUsage := Used / Status.ullTotalPhys * 100.0;
  end;

  if Status.ullTotalPageFile > 0 then
  begin
    Used := Status.ullTotalPageFile - Status.ullAvailPageFile;
    ASwapUsage := Used / Status.ullTotalPageFile * 100.0;
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
