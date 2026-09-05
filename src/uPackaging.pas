unit uPackaging;

{ Detects whether the running exe is packaged (MSIX/Store), at runtime rather
  than via a compile-time constant, since the same exe ships both ways.
  Set CDebugForceStorePackage to False before release. }

interface

const
  { True: IsStorePackage always reports packaged, for manually exercising the
    Store-only code paths (no GitHub check, no tray balloon, no menu item, no
    options checkbox) on a normal (non-MSIX) dev build. }
  CDebugForceStorePackage: Boolean = False;

function IsStorePackage: Boolean;

implementation

uses
  Winapi.Windows;

const
  { APPMODEL_ERROR_NO_PACKAGE (15700, not packaged) and any other unexpected
    error both fall through to FResult := False below. }
  ERROR_INSUFFICIENT_BUFFER = 122;

var
  FCached: Boolean = False;
  FResult: Boolean = False;

function GetCurrentPackageFullName(var packageFullNameLength: UINT32;
  packageFullName: PWideChar): LongInt; stdcall;
  external 'kernel32.dll' name 'GetCurrentPackageFullName';

function IsStorePackage: Boolean;
var
  Len: UINT32;
  Err: LongInt;
begin
  if CDebugForceStorePackage then
    Exit(True);
  if not FCached then
  begin
    Len := 0;
    Err := GetCurrentPackageFullName(Len, nil);
    { Any process identity (not just packaged ones) never changes for the
      lifetime of the process, so the first result can be cached. }
    FResult := Err = ERROR_INSUFFICIENT_BUFFER;
    FCached := True;
  end;
  Result := FResult;
end;

end.
