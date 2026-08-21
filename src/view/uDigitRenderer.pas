unit uDigitRenderer;

{ Draws Cpu/Mem/Swap percent digits: bitmap font sheet or GDI system font. }

interface

uses
  Vcl.Graphics,
  uLayoutTypes,
  uAssetStore;

type
  TDigitRenderer = class
  public
    class procedure DrawPercent(ADest: TCanvas; const ALayout: TViewLayout;
      AAssets: TAssetStore; const AVal: TDigitValue; AValue01: Double); static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Winapi.Windows;

const
  CFontGlyphs = 11; { 0..9 + space }

function FormatPercentText(APercent: Integer; ADigits: Integer; AFillZero: Boolean): string;
var
  S: string;
  i: Integer;
begin
  if APercent < 0 then
    APercent := 0;
  if APercent > 100 then
    APercent := 100;
  if ADigits < 1 then
    ADigits := 1;

  S := IntToStr(APercent);
  if Length(S) > ADigits then
    S := Copy(S, Length(S) - ADigits + 1, ADigits);

  if AFillZero then
  begin
    while Length(S) < ADigits do
      S := '0' + S;
  end
  else
  begin
    while Length(S) < ADigits do
      S := ' ' + S;
  end;

  { Ensure exactly ADigits chars (spaces already padded). }
  if Length(S) > ADigits then
    S := Copy(S, Length(S) - ADigits + 1, ADigits);
  Result := S;
  for i := 1 to Length(Result) do
    if (Result[i] <> ' ') and ((Result[i] < '0') or (Result[i] > '9')) then
      Result[i] := ' ';
end;

procedure DrawBitmapDigits(ADest: TCanvas; const ALayout: TViewLayout;
  AAssets: TAssetStore; const AVal: TDigitValue; const AText: string);
var
  FontBmp: Vcl.Graphics.TBitmap;
  GlyphW: Integer;
  GlyphH: Integer;
  i: Integer;
  Ch: Char;
  GlyphIndex: Integer;
  DestX: Integer;
begin
  if ALayout.FontFile = '' then
    Exit;

  FontBmp := AAssets.Graphic(ALayout, ALayout.FontFile);
  GlyphW := FontBmp.Width div CFontGlyphs;
  GlyphH := FontBmp.Height;
  if (GlyphW <= 0) or (GlyphH <= 0) then
    Exit;

  DestX := AVal.X;
  for i := 1 to Length(AText) do
  begin
    Ch := AText[i];
    if Ch = ' ' then
      GlyphIndex := 10
    else if (Ch >= '0') and (Ch <= '9') then
      GlyphIndex := Ord(Ch) - Ord('0')
    else
      GlyphIndex := 10;

    if ALayout.FontTransparent then
      TransparentBlt(ADest.Handle, DestX, AVal.Y, GlyphW, GlyphH,
        FontBmp.Canvas.Handle, GlyphIndex * GlyphW, 0, GlyphW, GlyphH,
        ColorToRGB(ALayout.FontMaskColor))
    else
      BitBlt(ADest.Handle, DestX, AVal.Y, GlyphW, GlyphH,
        FontBmp.Canvas.Handle, GlyphIndex * GlyphW, 0, SRCCOPY);

    Inc(DestX, GlyphW);
  end;
end;

procedure DrawSystemDigits(ADest: TCanvas; const AVal: TDigitValue; const AText: string);
var
  OldBk: Integer;
  OldColor: TColor;
  Styles: TFontStyles;
begin
  if Trim(AVal.FontName) = '' then
    Exit;

  Styles := [];
  if AVal.Bold then
    Include(Styles, fsBold);

  ADest.Font.Name := AVal.FontName;
  ADest.Font.Size := AVal.FontSize;
  ADest.Font.Style := Styles;
  ADest.Font.Color := AVal.Color;
  OldBk := SetBkMode(ADest.Handle, TRANSPARENT);
  OldColor := ADest.Font.Color;
  try
    ADest.TextOut(AVal.X, AVal.Y, AText);
  finally
    SetBkMode(ADest.Handle, OldBk);
    ADest.Font.Color := OldColor;
  end;
end;

class procedure TDigitRenderer.DrawPercent(ADest: TCanvas; const ALayout: TViewLayout;
  AAssets: TAssetStore; const AVal: TDigitValue; AValue01: Double);
var
  Percent: Integer;
  Text: string;
begin
  if not AVal.Enabled then
    Exit;

  Percent := Round(EnsureRange(AValue01, 0, 1) * 100.0);
  Text := FormatPercentText(Percent, AVal.Digits, AVal.FillZero);

  case AVal.Style of
    dsBitmap:
      DrawBitmapDigits(ADest, ALayout, AAssets, AVal, Text);
    dsSystem:
      DrawSystemDigits(ADest, AVal, Text);
  end;
end;

end.
