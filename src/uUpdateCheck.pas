unit uUpdateCheck;

{ GitHub Releases Latest: one-shot version check. No download or self-update.
  Set CDebugForceNewerRelease to False after the tray/menu UI is verified. }

interface

const
  { True: skip GitHub and pretend the next patch exists. Click opens /releases/latest. }
  CDebugForceNewerRelease = False;
  CGitHubLatestUrl = 'https://github.com/soramimi6/DiskLED/releases/latest';

type
  TUpdateCheckResult = record
    Found: Boolean;
    Version: string;
    PageUrl: string;
  end;

function NormalizeVersionText(const ARaw: string): string;
function CompareVersionText(const ALeft, ARight: string): Integer;
function VersionIsNewer(const ARemote, ALocal: string): Boolean;
function UpdateReleasePageUrl(const AVersion: string): string;
function TryFetchLatestRelease(out AResult: TUpdateCheckResult): Boolean;

implementation

uses
  System.SysUtils,
  System.Net.HttpClient,
  uAppStrings;

const
  CTagUrlPrefix = 'https://github.com/soramimi6/DiskLED/releases/tag/v';
  CHttpTimeoutMs = 8000;

function NormalizeVersionText(const ARaw: string): string;
var
  S: string;
begin
  S := Trim(ARaw);
  if (Length(S) > 0) and ((S[1] = 'v') or (S[1] = 'V')) then
    Delete(S, 1, 1);
  Result := Trim(S);
end;

procedure ParseVersionParts(const ARaw: string; out AMaj, AMin, ARel, ABld: Integer);
var
  S, Part: string;
  Parts: TArray<string>;
  i, N, V: Integer;
  Acc: array[0..3] of Integer;
begin
  AMaj := 0;
  AMin := 0;
  ARel := 0;
  ABld := 0;
  for i := 0 to 3 do
    Acc[i] := 0;
  S := NormalizeVersionText(ARaw);
  if S = '' then
    Exit;
  Parts := S.Split(['.']);
  N := Length(Parts);
  if N > 4 then
    N := 4;
  for i := 0 to N - 1 do
  begin
    Part := Trim(Parts[i]);
    if TryStrToInt(Part, V) and (V >= 0) then
      Acc[i] := V;
  end;
  AMaj := Acc[0];
  AMin := Acc[1];
  ARel := Acc[2];
  ABld := Acc[3];
end;

function CompareVersionText(const ALeft, ARight: string): Integer;
var
  LMaj, LMin, LRel, LBld: Integer;
  RMaj, RMin, RRel, RBld: Integer;
begin
  ParseVersionParts(ALeft, LMaj, LMin, LRel, LBld);
  ParseVersionParts(ARight, RMaj, RMin, RRel, RBld);
  if LMaj <> RMaj then
    Exit(LMaj - RMaj);
  if LMin <> RMin then
    Exit(LMin - RMin);
  if LRel <> RRel then
    Exit(LRel - RRel);
  Result := LBld - RBld;
end;

function VersionIsNewer(const ARemote, ALocal: string): Boolean;
begin
  Result := CompareVersionText(ARemote, ALocal) > 0;
end;

function FormatVersion(AMaj, AMin, ARel, ABld: Integer): string;
begin
  if ABld <> 0 then
    Result := Format('%d.%d.%d.%d', [AMaj, AMin, ARel, ABld])
  else
    Result := Format('%d.%d.%d', [AMaj, AMin, ARel]);
end;

function BumpPatchVersion(const AVersion: string): string;
var
  Maj, Min, Rel, Bld: Integer;
begin
  ParseVersionParts(AVersion, Maj, Min, Rel, Bld);
  Inc(Rel);
  Result := FormatVersion(Maj, Min, Rel, Bld);
end;

function UpdateReleasePageUrl(const AVersion: string): string;
var
  Ver: string;
begin
  if CDebugForceNewerRelease then
    Exit(CGitHubLatestUrl);
  Ver := NormalizeVersionText(AVersion);
  if Ver = '' then
    Exit(CGitHubLatestUrl);
  Result := CTagUrlPrefix + Ver;
end;

function TagFromLocation(const ALocation: string): string;
var
  S: string;
  P: Integer;
begin
  Result := '';
  S := Trim(ALocation);
  if S = '' then
    Exit;
  P := Pos('?', S);
  if P > 0 then
    S := Copy(S, 1, P - 1);
  while (Length(S) > 0) and (S[Length(S)] = '/') do
    Delete(S, Length(S), 1);
  P := LastDelimiter('/', S);
  if P > 0 then
    S := Copy(S, P + 1, MaxInt);
  Result := NormalizeVersionText(S);
end;

function FakeNewerRelease(out AResult: TUpdateCheckResult): Boolean;
begin
  AResult.Found := True;
  AResult.Version := BumpPatchVersion(GetProductVersionText);
  AResult.PageUrl := CGitHubLatestUrl;
  Result := True;
end;

function TryFetchLatestRelease(out AResult: TUpdateCheckResult): Boolean;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
  Location, Ver: string;
  UseFake: Boolean;
begin
  AResult.Found := False;
  AResult.Version := '';
  AResult.PageUrl := '';
  { Local copy so the compiler does not treat the GitHub path as dead when
    CDebugForceNewerRelease is True (H2077 on Result). }
  UseFake := CDebugForceNewerRelease;
  if UseFake then
  begin
    Result := FakeNewerRelease(AResult);
    Exit;
  end;

  Result := False;
  Client := THTTPClient.Create;
  try
    Client.HandleRedirects := False;
    Client.ConnectionTimeout := CHttpTimeoutMs;
    Client.ResponseTimeout := CHttpTimeoutMs;
    Client.UserAgent := 'DiskLED/' + GetProductVersionText +
      ' (+https://github.com/soramimi6/DiskLED)';
    try
      Resp := Client.Get(CGitHubLatestUrl);
    except
      Exit;
    end;
    if Resp = nil then
      Exit;
    Location := Trim(Resp.HeaderValue['Location']);
    Ver := TagFromLocation(Location);
    if Ver = '' then
      Exit;
    AResult.Found := True;
    AResult.Version := Ver;
    AResult.PageUrl := UpdateReleasePageUrl(Ver);
    Result := True;
  finally
    Client.Free;
  end;
end;

end.
