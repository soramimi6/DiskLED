unit uTrayIconComposer;

interface

uses
  Vcl.Graphics;

{ Returns a new icon: ABase scaled to ASize with ALetter drawn small in the
  bottom-right corner on a dark plate. Empty when ABase is empty. The caller
  owns the result. }
function ComposeLetterIcon(ABase: TIcon; ALetter: Char; ASize: Integer): TIcon;

implementation

uses
  Winapi.Windows,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ;

const
  CLetterEmRatio = 0.62;
  { Dark plate behind the letter, so it reads on light and dark taskbars
    alike. Padding and corner radius are fractions of the icon size. }
  CPlatePadRatio = 0.06;
  CPlateRadiusRatio = 0.14;
  CPlateAlpha = 200;

{ ABase as a 32bpp ARGB bitmap with its per-pixel alpha intact.
  TGPBitmap.Create(HICON) (GDI+ Bitmap::FromHICON) builds transparency from
  the AND mask only, so the LED's soft anti-aliased edge turns jagged. An icon
  without alpha (all zero) takes its transparency from the mask instead.
  nil when the icon's bitmaps can't be read. }
function CreateArgbBitmap(AIcon: HICON): TGPBitmap;
var
  Info: TIconInfo;
  Bmp: tagBITMAP;
  Bi: TBitmapInfo;
  DC: HDC;
  W, H, I, Y: Integer;
  Pixels, Mask: array of DWORD;
  HasAlpha: Boolean;
  Rect: TGPRect;
  Data: TBitmapData;
begin
  Result := nil;
  if not GetIconInfo(AIcon, Info) then
    Exit;
  try
    if (Info.hbmColor = 0) or
      (GetObject(Info.hbmColor, SizeOf(Bmp), @Bmp) = 0) then
      Exit;
    W := Bmp.bmWidth;
    H := Bmp.bmHeight;
    if (W <= 0) or (H <= 0) then
      Exit;
    FillChar(Bi, SizeOf(Bi), 0);
    Bi.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    Bi.bmiHeader.biWidth := W;
    Bi.bmiHeader.biHeight := -H;
    Bi.bmiHeader.biPlanes := 1;
    Bi.bmiHeader.biBitCount := 32;
    Bi.bmiHeader.biCompression := BI_RGB;
    SetLength(Pixels, W * H);
    DC := GetDC(0);
    try
      if GetDIBits(DC, Info.hbmColor, 0, H, @Pixels[0], Bi, DIB_RGB_COLORS) <> H then
        Exit;
      HasAlpha := False;
      for I := 0 to High(Pixels) do
        if (Pixels[I] and $FF000000) <> 0 then
        begin
          HasAlpha := True;
          Break;
        end;
      if not HasAlpha then
      begin
        { Mask: black (0) is opaque, white is transparent. }
        SetLength(Mask, W * H);
        if GetDIBits(DC, Info.hbmMask, 0, H, @Mask[0], Bi, DIB_RGB_COLORS) <> H then
          Exit;
        for I := 0 to High(Pixels) do
          if (Mask[I] and $00FFFFFF) = 0 then
            Pixels[I] := Pixels[I] or $FF000000
          else
            Pixels[I] := 0;
      end;
    finally
      ReleaseDC(0, DC);
    end;

    Result := TGPBitmap.Create(W, H, PixelFormat32bppARGB);
    Rect := MakeRect(0, 0, W, H);
    if Result.LockBits(Rect, ImageLockModeWrite, PixelFormat32bppARGB, Data) <> Ok then
    begin
      Result.Free;
      Result := nil;
      Exit;
    end;
    try
      for Y := 0 to H - 1 do
        Move(Pixels[Y * W], (PByte(Data.Scan0) + Y * Data.Stride)^, W * 4);
    finally
      Result.UnlockBits(Data);
    end;
  finally
    if Info.hbmColor <> 0 then
      DeleteObject(Info.hbmColor);
    if Info.hbmMask <> 0 then
      DeleteObject(Info.hbmMask);
  end;
end;

procedure AddRoundRect(APath: TGPGraphicsPath; X, Y, W, H, R: Single);
var
  D: Single;
begin
  D := R * 2;
  if D > W then
    D := W;
  if D > H then
    D := H;
  APath.AddArc(X, Y, D, D, 180, 90);
  APath.AddArc(X + W - D, Y, D, D, 270, 90);
  APath.AddArc(X + W - D, Y + H - D, D, D, 0, 90);
  APath.AddArc(X, Y + H - D, D, D, 90, 90);
  APath.CloseFigure;
end;

function ComposeLetterIcon(ABase: TIcon; ALetter: Char; ASize: Integer): TIcon;
var
  Target: TGPBitmap;
  Base: TGPBitmap;
  G: TGPGraphics;
  Family: TGPFontFamily;
  Path: TGPGraphicsPath;
  Plate: TGPGraphicsPath;
  Origin: TGPPointF;
  Bounds: TGPRectF;
  Fill: TGPSolidBrush;
  IconHandle: HICON;
  EmSize, Pad, PlateX, PlateY, Dx, Dy: Single;
begin
  Result := TIcon.Create;
  if ABase.Empty then
    Exit;
  Target := TGPBitmap.Create(ASize, ASize, PixelFormat32bppARGB);
  try
    G := TGPGraphics.Create(Target);
    try
      G.SetSmoothingMode(SmoothingModeAntiAlias);
      G.SetTextRenderingHint(TextRenderingHintAntiAlias);
      G.SetInterpolationMode(InterpolationModeHighQualityBicubic);
      G.Clear(0);
      Base := CreateArgbBitmap(ABase.Handle);
      if Base = nil then
        Base := TGPBitmap.Create(ABase.Handle);
      try
        G.DrawImage(Base, 0, 0, ASize, ASize);
      finally
        Base.Free;
      end;

      EmSize := ASize * CLetterEmRatio;
      Pad := ASize * CPlatePadRatio;
      if Pad < 1 then
        Pad := 1;
      Family := TGPFontFamily.Create('Segoe UI');
      Path := TGPGraphicsPath.Create;
      Plate := TGPGraphicsPath.Create;
      try
        Origin.X := 0;
        Origin.Y := 0;
        Path.AddString(ALetter, 1, Family, FontStyleBold, EmSize, Origin, nil);
        Path.GetBounds(Bounds);
        { Plate flush with the icon's bottom-right corner; the letter sits
          inside it with Pad on every side. }
        PlateX := ASize - (Bounds.Width + Pad * 2);
        PlateY := ASize - (Bounds.Height + Pad * 2);
        if PlateX < 0 then
          PlateX := 0;
        if PlateY < 0 then
          PlateY := 0;
        AddRoundRect(Plate, PlateX, PlateY, ASize - PlateX, ASize - PlateY,
          ASize * CPlateRadiusRatio);
        Fill := TGPSolidBrush.Create(MakeColor(CPlateAlpha, 0, 0, 0));
        try
          G.FillPath(Fill, Plate);
        finally
          Fill.Free;
        end;

        Dx := ASize - Pad - (Bounds.X + Bounds.Width);
        Dy := ASize - Pad - (Bounds.Y + Bounds.Height);
        G.TranslateTransform(Dx, Dy);
        Fill := TGPSolidBrush.Create(MakeColor(255, 255, 255, 255));
        try
          G.FillPath(Fill, Path);
        finally
          Fill.Free;
        end;
      finally
        Plate.Free;
        Path.Free;
        Family.Free;
      end;
    finally
      G.Free;
    end;
    if Target.GetHICON(IconHandle) = Ok then
      Result.Handle := IconHandle;
  finally
    Target.Free;
  end;
end;

end.
