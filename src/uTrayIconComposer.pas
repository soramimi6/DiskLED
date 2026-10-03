unit uTrayIconComposer;

interface

uses
  Vcl.Graphics;

{ Returns a new icon: ABase scaled to ASize with ALetter drawn small in the
  bottom-right corner. Empty when ABase is empty. The caller owns the result. }
function ComposeLetterIcon(ABase: TIcon; ALetter: Char; ASize: Integer): TIcon;

implementation

uses
  Winapi.Windows,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ;

const
  CLetterEmRatio = 0.62;
  COutlineWidthRatio = 0.12;

function ComposeLetterIcon(ABase: TIcon; ALetter: Char; ASize: Integer): TIcon;
var
  Target: TGPBitmap;
  Base: TGPBitmap;
  G: TGPGraphics;
  Family: TGPFontFamily;
  Path: TGPGraphicsPath;
  Origin: TGPPointF;
  Bounds: TGPRectF;
  Outline: TGPPen;
  Fill: TGPSolidBrush;
  IconHandle: HICON;
  EmSize, Dx, Dy: Single;
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
      G.Clear(0);
      Base := TGPBitmap.Create(ABase.Handle);
      try
        G.DrawImage(Base, 0, 0, ASize, ASize);
      finally
        Base.Free;
      end;

      EmSize := ASize * CLetterEmRatio;
      Family := TGPFontFamily.Create('Segoe UI');
      Path := TGPGraphicsPath.Create;
      try
        Origin.X := 0;
        Origin.Y := 0;
        Path.AddString(ALetter, 1, Family, FontStyleBold, EmSize, Origin, nil);
        Path.GetBounds(Bounds);
        Dx := ASize - (Bounds.X + Bounds.Width);
        Dy := ASize - (Bounds.Y + Bounds.Height);
        G.TranslateTransform(Dx, Dy);

        Outline := TGPPen.Create(MakeColor(220, 0, 0, 0), ASize * COutlineWidthRatio);
        try
          Outline.SetLineJoin(LineJoinRound);
          G.DrawPath(Outline, Path);
        finally
          Outline.Free;
        end;
        Fill := TGPSolidBrush.Create(MakeColor(255, 255, 255, 255));
        try
          G.FillPath(Fill, Path);
        finally
          Fill.Free;
        end;
      finally
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
