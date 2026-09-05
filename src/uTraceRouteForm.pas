unit uTraceRouteForm;

{ TraceRouteResult window: shows the current Ping target's route. Tracert
  only ever runs (a) when this window is shown, (b) on its refresh button —
  never on the periodic Ping cycle, so normal operation gains no extra
  network traffic. Controls are created in code (no .dfm layout), matching
  uDashboardForm's convention for this project's secondary windows. }

interface

uses
  System.Classes,
  Winapi.Messages,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Vcl.Graphics,
  uCollector,
  uTracertCollector;

type
  TTraceRouteForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FCollector: TMetricsCollector;
    FTracert: TTracertCollector;
    FHeaderPaint: TPaintBox;
    FListBorder: TPanel;
    FListHeaderPaint: TPaintBox;
    FList: TListView;
    FBtnRefresh: TButton;
    FBtnClose: TButton;
    FLastResult: TTracertResult;
    FHasResult: Boolean;
    FBusy: Boolean;
    FLastMeasuredAt: TDateTime;
    procedure HeaderPaint(Sender: TObject);
    procedure ListHeaderPaint(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    procedure TracertHop(const AHop: TTracertHop);
    procedure TracertHostName(ATtl: Integer; const AHostName: string);
    procedure TracertComplete(const AResult: TTracertResult);
    procedure ApplyTheme;
    procedure RunTracert;
    procedure WMSettingChange(var Message: TWMSettingChange); message WM_SETTINGCHANGE;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent; ACollector: TMetricsCollector); reintroduce;
    destructor Destroy; override;
  end;

implementation

{$R *.dfm}

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.UxTheme,
  uAppStrings,
  uMetricsTypes,
  uDashboardTheme;

const
  CListHeaderHeight = 24;
  CColTtlW = 48;
  CColIpW = 140;
  CColHostW = 280;
  CColRttW = 90;

constructor TTraceRouteForm.Create(AOwner: TComponent; ACollector: TMetricsCollector);
begin
  FCollector := ACollector;
  inherited Create(AOwner);
end;

destructor TTraceRouteForm.Destroy;
begin
  FTracert.Free;
  inherited;
end;

procedure TTraceRouteForm.CreateWnd;
begin
  inherited;
  { Per-HWND DWM attribute: must be reasserted on every handle (re)creation,
    same as uDashboardForm's CreateWnd. }
  ApplyHudTitleBar(Handle);
end;

procedure TTraceRouteForm.FormCreate(Sender: TObject);
const
  CMargin = 12;
  CHeaderHeight = 56;
  CButtonHeight = 28;
  CButtonWidth = 140;
begin
  Caption := S('trace.title');
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 700;
  ClientHeight := 560;
  Constraints.MinWidth := 520;
  Constraints.MinHeight := 380;

  FTracert := TTracertCollector.Create;
  FTracert.OnHop := TracertHop;
  FTracert.OnHostName := TracertHostName;
  FTracert.OnComplete := TracertComplete;

  FHeaderPaint := TPaintBox.Create(Self);
  FHeaderPaint.Parent := Self;
  FHeaderPaint.Align := alTop;
  FHeaderPaint.Height := CHeaderHeight;
  FHeaderPaint.OnPaint := HeaderPaint;

  FBtnRefresh := TButton.Create(Self);
  FBtnRefresh.Parent := Self;
  FBtnRefresh.Caption := S('trace.refresh');
  FBtnRefresh.SetBounds(CMargin, ClientHeight - CButtonHeight - CMargin,
    CButtonWidth, CButtonHeight);
  FBtnRefresh.Anchors := [akLeft, akBottom];
  FBtnRefresh.OnClick := BtnRefreshClick;

  FBtnClose := TButton.Create(Self);
  FBtnClose.Parent := Self;
  FBtnClose.Caption := S('trace.close');
  FBtnClose.SetBounds(ClientWidth - CButtonWidth - CMargin,
    ClientHeight - CButtonHeight - CMargin, CButtonWidth, CButtonHeight);
  FBtnClose.Anchors := [akRight, akBottom];
  FBtnClose.OnClick := BtnCloseClick;

  { A 1px panel behind the header strip + list stands in for a themed
    border: TListView's own bsSingle edge is a fixed-color OS 3D sunken
    frame that ignores app theming entirely. }
  FListBorder := TPanel.Create(Self);
  FListBorder.Parent := Self;
  FListBorder.BevelOuter := bvNone;
  FListBorder.SetBounds(CMargin, CHeaderHeight,
    ClientWidth - CMargin * 2,
    ClientHeight - CHeaderHeight - CButtonHeight - CMargin * 2);
  FListBorder.Anchors := [akLeft, akTop, akRight, akBottom];

  FListHeaderPaint := TPaintBox.Create(Self);
  FListHeaderPaint.Parent := FListBorder;
  FListHeaderPaint.SetBounds(1, 1, FListBorder.Width - 2, CListHeaderHeight);
  FListHeaderPaint.Anchors := [akLeft, akTop, akRight];
  FListHeaderPaint.OnPaint := ListHeaderPaint;

  FList := TListView.Create(Self);
  FList.Parent := FListBorder;
  FList.BorderStyle := bsNone;
  FList.ShowColumnHeaders := False;
  FList.ReadOnly := True;
  FList.RowSelect := True;
  FList.ViewStyle := vsReport;
  { TListView's grid lines always draw in a fixed OS color with no way to
    recolor them, unlike everything else here — they'd clash with the dark
    palette, so leave rows separated by height/selection highlight only. }
  FList.GridLines := False;
  FList.SetBounds(1, 1 + CListHeaderHeight, FListBorder.Width - 2,
    FListBorder.Height - 2 - CListHeaderHeight);
  FList.Anchors := [akLeft, akTop, akRight, akBottom];
  { Explorer visual styles otherwise keep the native (light) list body
    colors regardless of Color/Font.Color; disabling theming for just this
    control lets our own palette apply. }
  FList.HandleNeeded;
  SetWindowTheme(FList.Handle, '', '');
  with FList.Columns.Add do
    Width := CColTtlW;
  with FList.Columns.Add do
    Width := CColIpW;
  with FList.Columns.Add do
    Width := CColHostW;
  with FList.Columns.Add do
    Width := CColRttW;

  ApplyTheme;
end;

procedure TTraceRouteForm.ApplyTheme;
var
  Pal: THudPalette;
begin
  Pal := HudPalette;
  Color := Pal.Bg;
  Font.Color := Pal.TextPrimary;
  FListBorder.Color := Pal.CardBorder;
  FList.Color := Pal.Card;
  FList.Font.Color := Pal.TextPrimary;
  if HandleAllocated then
    ApplyHudTitleBar(Handle);
  FHeaderPaint.Invalidate;
  FListHeaderPaint.Invalidate;
end;

procedure TTraceRouteForm.WMSettingChange(var Message: TWMSettingChange);
begin
  inherited;
  if (Message.Section <> nil) and
    SameText(string(Message.Section), 'ImmersiveColorSet') then
    ApplyTheme;
end;

procedure TTraceRouteForm.ListHeaderPaint(Sender: TObject);
var
  Pal: THudPalette;
  Canvas: TCanvas;
  R: TRect;
  X: Integer;
begin
  Pal := HudPalette;
  Canvas := FListHeaderPaint.Canvas;
  R := FListHeaderPaint.ClientRect;
  Canvas.Brush.Color := Pal.Card;
  Canvas.FillRect(R);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := Pal.TextMuted;

  X := 4;
  Canvas.TextOut(X, 4, S('trace.col_ttl'));
  Inc(X, CColTtlW);
  Canvas.TextOut(X, 4, S('trace.col_ip'));
  Inc(X, CColIpW);
  Canvas.TextOut(X, 4, S('trace.col_host'));
  Inc(X, CColHostW);
  Canvas.TextOut(X, 4, S('trace.col_rtt'));

  Canvas.Pen.Color := Pal.CardBorder;
  Canvas.MoveTo(R.Left, R.Bottom - 1);
  Canvas.LineTo(R.Right, R.Bottom - 1);
end;

procedure TTraceRouteForm.HeaderPaint(Sender: TObject);
var
  Pal: THudPalette;
  Canvas: TCanvas;
  R: TRect;
  Line1, Line2: string;
begin
  Pal := HudPalette;
  Canvas := FHeaderPaint.Canvas;
  R := FHeaderPaint.ClientRect;
  Canvas.Brush.Color := Pal.Bg;
  Canvas.FillRect(R);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';

  if FBusy then
    Line1 := S('trace.running')
  else if FHasResult then
  begin
    Line1 := S('trace.target') + ': ' + FLastResult.TargetHost;
    if (FLastResult.TargetIp <> '') and (FLastResult.TargetIp <> FLastResult.TargetHost) then
      Line1 := Line1 + ' (' + FLastResult.TargetIp + ')';
  end
  else
    Line1 := S('trace.target') + ': ' + #$2014;

  Canvas.Font.Size := 11;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := Pal.TextPrimary;
  Canvas.TextOut(12, 6, Line1);

  if FHasResult and (not FBusy) then
  begin
    Line2 := Format('%s: %d   %s: %.0f ms   %s: %s', [S('trace.hops'), FLastResult.HopCount,
      S('trace.total'), FLastResult.TotalMs,
      S('trace.measured_at'), DateTimeToStr(FLastMeasuredAt)]);
    if not FLastResult.Completed then
      Line2 := Line2 + '   ' + S('trace.unreachable');
  end
  else
    Line2 := '';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];
  Canvas.Font.Color := Pal.TextMuted;
  Canvas.TextOut(12, 30, Line2);
end;

procedure TTraceRouteForm.RunTracert;
begin
  if FBusy then
    Exit;
  FBusy := True;
  FHasResult := False;
  FList.Items.Clear;
  FHeaderPaint.Invalidate;
  FBtnRefresh.Enabled := False;
  FTracert.RunAsync(FCollector.CurrentPingTarget);
  if FCollector <> nil then
    FCollector.RequestPing;
end;

procedure TTraceRouteForm.TracertHop(const AHop: TTracertHop);
var
  Item: TListItem;
  RttText: string;
begin
  Item := FList.Items.Add;
  Item.Caption := IntToStr(AHop.Ttl);
  if AHop.Ok then
  begin
    Item.SubItems.Add(AHop.Ip);
    Item.SubItems.Add(AHop.HostName);
    if AHop.RttMs >= 10 then
      RttText := Format('%.0f ms', [AHop.RttMs])
    else
      RttText := Format('%.1f ms', [AHop.RttMs]);
    Item.SubItems.Add(RttText);
  end
  else
  begin
    Item.SubItems.Add('*');
    Item.SubItems.Add('');
    Item.SubItems.Add('*');
  end;
end;

procedure TTraceRouteForm.TracertHostName(ATtl: Integer; const AHostName: string);
var
  i: Integer;
begin
  for i := 0 to FList.Items.Count - 1 do
    if FList.Items[i].Caption = IntToStr(ATtl) then
    begin
      { Column order: TTL, IP, Host, RTT — Host is SubItems[1]. }
      if FList.Items[i].SubItems.Count > 1 then
        FList.Items[i].SubItems[1] := AHostName;
      Break;
    end;
end;

procedure TTraceRouteForm.TracertComplete(const AResult: TTracertResult);
begin
  FLastResult := AResult;
  FHasResult := True;
  FLastMeasuredAt := Now;
  FBusy := False;
  FBtnRefresh.Enabled := True;
  FHeaderPaint.Invalidate;
end;

procedure TTraceRouteForm.BtnRefreshClick(Sender: TObject);
begin
  RunTracert;
end;

procedure TTraceRouteForm.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TTraceRouteForm.FormShow(Sender: TObject);
begin
  ApplyTheme;
  RunTracert;
end;

procedure TTraceRouteForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caHide;
end;

end.
