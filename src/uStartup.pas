unit uStartup;

{ Current-user Run key registration (no admin). }

interface

type
  TStartup = class
  public
    class function IsRegistered: Boolean; static;
    class procedure SetRegistered(AEnabled: Boolean); static;
  end;

implementation

uses
  System.SysUtils,
  System.Win.Registry,
  Winapi.Windows;

const
  CRunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  CValueName = 'DiskLED';

class function TStartup.IsRegistered: Boolean;
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(CRunKey) then
      Result := Reg.ValueExists(CValueName);
  finally
    Reg.Free;
  end;
end;

class procedure TStartup.SetRegistered(AEnabled: Boolean);
var
  Reg: TRegistry;
  Exe: string;
begin
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(CRunKey, True) then
      raise Exception.Create('Cannot open HKCU Run key');

    if AEnabled then
    begin
      Exe := ParamStr(0);
      Reg.WriteString(CValueName, '"' + Exe + '"');
    end
    else if Reg.ValueExists(CValueName) then
      Reg.DeleteValue(CValueName);
  finally
    Reg.Free;
  end;
end;

end.
