unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Bluetooth,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, FMX.Controls.Presentation, FMX.DialogService,
  FMX.ScrollBox, FMX.Memo, FMX.Edit, FMX.TabControl,
{$IFDEF ANDROID}
  Androidapi.JNIBridge,
  AndroidApi.JNI.Media,
{$ENDIF}
  Tools, FMX.ListBox;

type
  TMainForm = class(TForm)
    MainFormToolBar: TToolBar;
    ApplicationCloseButton: TSpeedButton;
    ApplicationTitleLabel: TLabel;
    ApplicationIconImage: TImage;
    DiscoverPanel: TPanel;
    ConnectButton: TButton;
    AnimatedIndicator: TAniIndicator;
    WaitTimer: TTimer;
    CommonTabControl: TTabControl;
    ControlTab: TTabItem;
    DebugTab: TTabItem;
    TopBlackButton: TButton;
    DebugMemo: TMemo;
    DebugEditPanel: TPanel;
    DebugEdit: TEdit;
    TopRedButton: TButton;
    BottomBlackButton: TButton;
    BottomWhiteButton: TButton;
    HeartBeat: TTimer;
    Timer: TTimer;
    TimerGroupBox: TGroupBox;
    DurationLabel: TLabel;
    DurationEdit: TEdit;
    UnitComboBox: TComboBox;
    TopBlackCheckBox: TCheckBox;
    BottomBlackCheckBox: TCheckBox;
    TopRedCheckBox: TCheckBox;
    BottomWhiteCheckBox: TCheckBox;
    ExposureButton: TButton;
    ProtectCheckBox: TCheckBox;
    procedure MainFormOnKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure ApplicationCloseButtonOnClick(Sender: TObject);
    procedure MainFormOnShow(Sender: TObject);
    procedure WaitTimerOnTimer(Sender: TObject);
    procedure WaitTimerOnSetup(Sender: TObject);
    procedure WaitTimerOnClose(Sender: TObject);
    procedure ConnectButtonOnClick(Sender: TObject);
    procedure DebugEditOnKeyUp(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
    procedure DebugMemoOnMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure DebugEditOnEnter(Sender: TObject);
    procedure DebugEditOnExit(Sender: TObject);
    procedure MainFormOnClose(Sender: TObject; var Action: TCloseAction);
    procedure TopBlackButtonOnClick(Sender: TObject);
    procedure BottomBlackButtonOnClick(Sender: TObject);
    procedure TopRedButtonOnClick(Sender: TObject);
    procedure BootomWhiteButtonOnClick(Sender: TObject);
    procedure HeartBeatOnTime(Sender: TObject);
    procedure TimerOnTimer(Sender: TObject);
    procedure ExposureButtonOnClick(Sender: TObject);
  private
    { Private declarations }
    Scanning: Boolean;
    ScanningStart: DWORD;
    Ready: Boolean;
    MainFormSender: TObject;
    FBluetoothManager: TBluetoothManager;
    FDiscoverDevices: TBluetoothDeviceList;
    ExposureBox: TBluetoothDevice;
    FSocket: TBluetoothSocket;
    FAdapter: TBluetoothAdapter;

    procedure Setup;
    procedure StartBluetoothScan;
    function ManagerConnected: Boolean;
    function IsBluetoothEnabled: Boolean;
    procedure ShowRetryMessage(const TheMessage: String);
    procedure DevicesDiscoveryEnd(const Sender: TObject; const ADevices: TBluetoothDeviceList);
    function SendMessageToExposureBox(const TheMessage: String): String;
  public
    { Public declarations }
    procedure ClearConnectionFlags;
    procedure ClearBluetoothComponents;
    procedure ClearFormComponents;
    procedure SetScanning;
    procedure ResetScan;
    procedure ExposureBoxReset;

    procedure TopAndBlackLightsOnAndOff;

    procedure ClearFlagsAndStates;
    procedure SetFlagsAndStates;
    procedure SetTimerDuration;
    procedure ClearInitialStatesOfLights;
    procedure UpdateStatesOfLights;
    procedure SetInitialStatesOfLights;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}
{$R *.LgXhdpiPh.fmx ANDROID}

const
  CONN_BTN_SCAN = 'Scan...';
  CONN_BTN_SCANNING = 'Scanning...';
  CONN_BTN_CONNECTING = 'Connecting...';
  CONN_BTN_CONNECTED = 'Connected...';
  CONN_BTN_PAIRING = 'Pairing...';

const
  ScanningTime = 20000;
  WaitTime = 25000;
  ExposureBoxIdent: String = 'Exposure Box';
  ExposureBoxServiceGUID = '{00001101-0000-1000-8000-00805F9B34FB}';
  ExposureBoxPairingRetryLimit = 10;

var
  DebugEditFocused: Boolean = False;
  IsIdle: Boolean = True;

//
//  Protocol
//    Host ---> <Send Command> ---> Client
//    Host <--- <Received Response> <--- Client
//
//  Command Format:
//  <Command> ::= @<OpCode>;<Operand>
//  <OpCode>  ::= {Integer}
//  <Operand> ::= nil
//              | "<String>;
//              | #<Integer>;
//              | $<Float>;
//
//  Received Response Format
//  <Received Response> ::= !<String><Command Completed>
//  <String>            ::= nil
//                        | {Strring}
//  <Command Completed> ::= ;
//
const
  COMMAND_DELIMITER = ';';
  COMMAND_PREFIX    = '@';
  UNKNOWN_PREFIX    = '?';
  UNKNOWN_RESPONSE  = '?;';
  RESPONSE_PREFIX   = '!';
  STRING_PREFIX     = '"';
  INTEGER_PREFIX    = '#';
  FLOAT_PREFIX      = '$';
  CMD_NOP           = 0;
  CMD_ECHO          = 1;
  CMD_RESET         = 2;
  CMD_VERSION       = 3;
  CMD_TOPBLACKLIGHT_ON     = 4;
  CMD_TOPBLACKLIGHT_OFF    = 5;
  CMD_BOTTOMBLACKLIGHT_ON  = 6;
  CMD_BOTTOMBLACKLIGHT_OFF = 7;
  CMD_BOTTOMWHITELIGHT_ON  = 8;
  CMD_BOTTOMWHITELIGHT_OFF = 9;
  CMD_TOPREDLIGHT_ON       = 10;
  CMD_TOPREDLIGHT_OFF      = 11;
  CMD_TOPANDBOTTOMBLACKLIGHT_ON      = 12;
  CMD_TOPANDBOTTOMBLACKLIGHT_OFF     = 13;

//  Timer Control Variables;
var
  TopBlackLightsFlag: Boolean;
  BottomBlackLightsFlag: Boolean;
  TopAndBottomBlackLightsFlag: Boolean;
  TopRedLightsFlag: Boolean;
  BottomWhiteLightsFlag: Boolean;
  ProtectInitialStateFlag: Boolean;

  TopBlackLightsInitialState: Boolean;
  BottomBlackLightsInitialState: Boolean;
  TopRedLightsInitialState: Boolean;
  BottomWhiteLightsInitialState: Boolean;

  TimerDuration: LongInt;


procedure TMainForm.ClearFlagsAndStates;
begin
  TopBlackLightsFlag := FALSE;
  BottomBlackLightsFlag := FALSE;
  TopAndBottomBlackLightsFlag := FALSE;
  TopRedLightsFlag := FALSE;
  BottomWhiteLightsFlag := FALSE;

  ProtectInitialStateFlag := FALSE;

  TopBlackLightsInitialState := FALSE;
  BottomBlackLightsInitialState := FALSE;
  TopRedLightsInitialState := FALSE;
  BottomWhiteLightsInitialState := FALSE;
end;

procedure TMainForm.SetFlagsAndStates;
var
  P: Integer;
begin
  ClearFlagsAndStates;

  if TopBlackCheckBox.IsChecked = TRUE then TopBlackLightsFlag := TRUE;
  if BottomBlackCheckBox.IsChecked = TRUE then BottomBlackLightsFlag := TRUE;
  if (TopBlackLightsFlag = TRUE) and (BottomBlackLightsFlag = TRUE) then
    TopAndBottomBlackLightsFlag := TRUE;
  if TopRedCheckBox.IsChecked = TRUE then TopRedLightsFlag := TRUE;
  if BottomWhiteCheckBox.IsChecked = TRUE then BottomWhiteLightsFlag := TRUE;

  if ProtectCheckBox.IsChecked = TRUE then ProtectInitialStateFlag := TRUE;

  P := Pos('OFF', TopBlackButton.Text);
  if P > 0 then TopBlackLightsInitialState := TRUE;
  P := Pos('OFF', BottomBlackButton.Text);
  if P > 0 then BottomBlackLightsInitialState := TRUE;
  P := Pos('OFF', TopRedButton.Text);
  if P > 0 then TopRedLightsInitialState := TRUE;
  P := Pos('OFF', BottomWhiteButton.Text);
  if P > 0 then BottomWhiteLightsInitialState := TRUE;
end;

procedure TMainForm.ClearInitialStatesOfLights;
var
  P, Q: Integer;
begin
  P := Pos('OFF', TopBlackButton.Text);
  Q := Pos('OFF', BottomBlackButton.Text);
  if (P > 0) and (Q > 0) then TopAndBlackLightsOnAndOff
  else
  begin
    P := Pos('OFF', TopBlackButton.Text);
    if P > 0 then TopBlackButtonOnClick(Self);
    P := Pos('OFF', BottomBlackButton.Text);
    if P > 0 then BottomBlackButtonOnClick(Self);
  end;

  P := Pos('OFF', TopRedButton.Text);
  if P > 0 then TopRedButtonOnClick(Self);
  P := Pos('OFF', BottomWhiteButton.Text);
  if P > 0 then BootomWhiteButtonOnClick(Self);
end;

procedure TMainForm.UpdateStatesOfLights;
begin
  if ((TopBlackLightsInitialState = TRUE) and (TopBlackLightsFlag = FALSE)) and
     ((BottomBlackLightsInitialState = TRUE) and (BottomBlackLightsFlag = FALSE)) then TopAndBlackLightsOnAndOff
  else
  begin
    if (TopBlackLightsInitialState = TRUE) and (TopBlackLightsFlag = FALSE) then TopBlackButtonOnClick(Self);
    if (BottomBlackLightsInitialState = TRUE) and (BottomBlackLightsFlag = FALSE) then BottomBlackButtonOnClick(Self);
  end;

  if ((TopBlackLightsInitialState = FALSE) and (TopBlackLightsFlag = TRUE)) and
     ((BottomBlackLightsInitialState = FALSE) and (BottomBlackLightsFlag = TRUE)) then TopAndBlackLightsOnAndOff
  else
  begin
    if (TopBlackLightsInitialState = FALSE) and (TopBlackLightsFlag = TRUE) then TopBlackButtonOnClick(Self);
    if (BottomBlackLightsInitialState = FALSE) and (BottomBlackLightsFlag = TRUE) then BottomBlackButtonOnClick(Self);
  end;

  if (TopRedLightsInitialState = TRUE) and (TopRedLightsFlag = FALSE) then TopRedButtonOnClick(Self);
  if (TopRedLightsInitialState = FALSE) and (TopRedLightsFlag = TRUE) then TopRedButtonOnClick(Self);

  if (BottomWhiteLightsInitialState = TRUE) and (BottomWhiteLightsFlag = FALSE) then BootomWhiteButtonOnClick(Self);
  if (BottomWhiteLightsInitialState = FALSE) and (BottomWhiteLightsFlag = TRUE) then BootomWhiteButtonOnClick(Self);
end;

procedure TMainForm.SetInitialStatesOfLights;
begin
  if TopBlackLightsInitialState and BottomBlackLightsInitialState then TopAndBlackLightsOnAndOff
  else
  begin
    if TopBlackLightsInitialState then TopBlackButtonOnClick(Self);
    if BottomBlackLightsInitialState then BottomBlackButtonOnClick(Self);
  end;
  if TopRedLightsInitialState then TopRedButtonOnClick(Self);
  if BottomWhiteLightsInitialState then BootomWhiteButtonOnClick(Self);
end;

procedure TMainForm.SetTimerDuration;
var
  F: Double;
begin
  if Length(DurationEdit.Text) < 1 then DurationEdit.Text := '1';
  F := StrToFloat(DurationEdit.Text);
  case UnitComboBox.ItemIndex of
    1: F := 1000 * F;         // Secons to miliseconds
    2: F := 60000 * F;        // Minutes to miliseconds
    3: F := 3600000 * F;      // Hours to miliseconds
  end;
  TimerDuration := Trunc(F);
end;

procedure TMainForm.WaitTimerOnTimer(Sender: TObject);
var
  Elapsed: DWORD;
  Paired: Boolean;
  I: Integer;
begin
  Elapsed := TThread.GetTickCount - ScanningStart;
  if  (not Assigned(ExposureBox)) and (Elapsed <= WaitTime) then WaitTimer.Enabled := True
  else
  begin
    FBluetoothManager.CancelDiscovery;
    WaitTimer.Enabled := False;
    Scanning := False;
    if Assigned(ExposureBox) then
    begin
      ConnectButton.Text := CONN_BTN_PAIRING;
      for I := 0 to ExposureBoxPairingRetryLimit do
      begin
        Paired := ExposureBox.IsPaired;
        if not Paired then
        begin
          Paired := FAdapter.Pair(ExposureBox);
          Sleep(1000);
          Application.ProcessMessages;
        end
        else
          Break;
      end;
      if not Paired then
      begin
        // Error
        ResetScan;
        ShowRetryMessage('"Exposure Box" not Paired. Retry ?');
        Exit;
      end;
      //  Paired
      if Paired then
      begin
        ConnectButton.Text := CONN_BTN_CONNECTING;
        FSocket := ExposureBox.CreateClientSocket(StringToGUID(ExposureBoxServiceGUID), False);
        if FSocket = nil then
        begin
          // Error
          ResetScan;
          ShowRetryMessage('"Exposure Box" Paired, But socket can not be created. Retry ?');
          Exit;
        end
        else
        begin
          if FSocket.Connected = FALSE then FSocket.Connect;
          Ready := True;
        end;
      end;
      if Ready then
      begin
        //
        //    Exposure Box Ready & Running
        //
        ConnectButton.Text := CONN_BTN_CONNECTED;
        AnimatedIndicator.Enabled := False;
        AnimatedIndicator.Visible := False;
        CommonTabControl.Enabled := True;
        CommonTabControl.Visible := True;
        DebugMemo.Lines.Clear;
        DebugMemo.Lines.Add('Exposure Box Ready.');
      end;
    end
    else
    begin
      // Error
      ResetScan;
      ShowRetryMessage('"Exposure Box" not found. Retry ?');
      Exit;
    end;
  end
end;

procedure TMainForm.DebugEditOnEnter(Sender: TObject);
begin
  DebugEditFocused := True;
end;

procedure TMainForm.DebugEditOnExit(Sender: TObject);
begin
  DebugEdit.ResetFocus;
  DebugEditFocused := False;
end;

function TMainForm.SendMessageToExposureBox(const TheMessage: String): String;
var
  ToSend: TBytes;
  FromReceive: TBytes;
  ToSendString: String;
begin
  Result := '';
  if Assigned(FSocket) and FSocket.Connected then
  begin
    IsIdle := False;
    if TheMessage[0] <> COMMAND_PREFIX then
      ToSendString := COMMAND_PREFIX + IntToStr(CMD_ECHO) + COMMAND_DELIMITER + TheMessage + COMMAND_DELIMITER
    else
      ToSendString := TheMessage;
    DebugMemo.Lines.Add('S: ' + ToSendString);
    ToSend := TEncoding.UTF8.GetBytes( ToSendString );
    FSocket.SendData(ToSend);
//    Sleep(10);
    FromReceive := FSocket.ReceiveData;
    Result := TEncoding.UTF8.GetString(FromReceive);
    DebugMemo.Lines.Add('R: ' + Result);
    IsIdle := True;
    if Result[0] = COMMAND_PREFIX then
      MainForm.MainFormOnShow(MainFormSender);
  end;
end;

procedure TMainForm.DebugEditOnKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
var
  Received: String;
begin
  if Key = vkReturn then
  begin
    DebugEdit.ResetFocus;
    DebugEditFocused := False;
    Received := SendMessageToExposureBox(DebugEdit.Text);
    DebugMemo.Lines.Add(Received);
    DebugEdit.Text := '';
  end;
end;

procedure TMainForm.DebugMemoOnMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if DebugEditFocused then
  begin
    DebugEdit.ResetFocus;
    DebugEditFocused := False;
  end;
end;

procedure TMainForm.DevicesDiscoveryEnd(const Sender: TObject; const ADevices: TBluetoothDeviceList);
  var
    I: Integer;
  begin
    if ADevices.Count > 0 then
    begin
      FDiscoverDevices := ADevices;
      for I := 0 to ADevices.Count - 1 do
      begin
        if (ExposureBox = nil) and (ADevices[I].DeviceName = ExposureBoxIdent) then
        begin
          ExposureBox := ADevices[I];
          Break;
        end;
      end;
    end;
end;


procedure TMainForm.StartBluetoothScan;
begin
  ScanningStart := TThread.GetTickCount;
  WaitTimer.Interval := 1000; //  5s
  WaitTimer.OnTimer := WaitTimerOnTimer;
  WaitTimer.Enabled := True;
  FBluetoothManager.OnDiscoveryEnd := DevicesDiscoveryEnd;
  FBluetoothManager.StartDiscovery(ScanningTime);
end;

procedure TMainForm.ExposureBoxReset;
var
  Returned: String;
begin
  Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_RESET) + COMMAND_DELIMITER);
  //  Do not Check
end;

procedure TMainForm.ExposureButtonOnClick(Sender: TObject);
var
  P: Integer;
begin
  SetFlagsAndStates;
  SetTimerDuration;
  Timer.Interval := TimerDuration;
//  Timer.Interval := 15000;

  P := Pos('Run', ExposureButton.Text);
  ExposureButton.Text := Copy(ExposureButton.Text, 0, P-1) + 'Running';

  UpdateStatesOfLights;
  Timer.Enabled := TRUE;
end;

procedure TMainForm.HeartBeatOnTime(Sender: TObject);
var
  Returned: String;
begin
  //  Send Heartbeat
  Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_NOP) + COMMAND_DELIMITER);
  HeartBeat.Enabled := TRUE;
end;

procedure TMainForm.TimerOnTimer(Sender: TObject);
var
  P: Integer;
begin
  Timer.Enabled := FALSE;
  if (not ProtectInitialStateFlag) then ClearInitialStatesOfLights
  else
    UpdateStatesOfLights;
  P := Pos('Running', ExposureButton.Text);
  ExposureButton.Text := Copy(ExposureButton.Text, 0, P-1) + 'Run';
  Sound(1000); // 1 Second Beep
end;

procedure TMainForm.TopAndBlackLightsOnAndOff;
var
  P, Q: Integer;
  Returned: String;
begin
  P := Pos('ON', TopBlackButton.Text);
  Q := Pos('ON', BottomBlackButton.Text);
  if (P > 0) and (Q > 0) then
  begin
    Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_TOPANDBOTTOMBLACKLIGHT_ON) + COMMAND_DELIMITER);
    if Returned = '!;' then
    begin
      TopBlackButton.Text := Copy(TopBlackButton.Text, 0, P-1) + 'OFF';
      BottomBlackButton.Text := Copy(BottomBlackButton.Text, 0, Q-1) + 'OFF';
    end
    else
      ShowMessageDialog('ERROR DETECTED...');
    Exit;
  end
  else
  begin
    P := Pos('OFF', TopBlackButton.Text);
    Q := Pos('OFF', BottomBlackButton.Text);
    if (P > 0) and (Q > 0) then
    begin
      Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_TOPANDBOTTOMBLACKLIGHT_OFF) + COMMAND_DELIMITER);
      if Returned = '!;' then
      begin
        TopBlackButton.Text := Copy(TopBlackButton.Text, 0, P-1) + 'ON';
        BottomBlackButton.Text := Copy(BottomBlackButton.Text, 0, Q-1) + 'ON';
      end
      else
        ShowMessageDialog('ERROR DETECTED...');
      Exit;
    end
  end;
end;

procedure TMainForm.TopBlackButtonOnClick(Sender: TObject);
var
  P: Integer;
  Returned: String;
begin
  P := Pos('ON', TopBlackButton.Text);
  if P > 0 then
  begin
    Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_TOPBLACKLIGHT_ON) + COMMAND_DELIMITER);
    if Returned = '!;' then TopBlackButton.Text := Copy(TopBlackButton.Text, 0, P-1) + 'OFF'
    else
      ShowMessageDialog('ERROR DETECTED...');
    Exit;
  end
  else
  begin
    P := Pos('OFF', TopBlackButton.Text);
    if P > 0 then
    begin
      Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_TOPBLACKLIGHT_OFF) + COMMAND_DELIMITER);
      if Returned = '!;' then TopBlackButton.Text := Copy(TopBlackButton.Text, 0, P-1) + 'ON'
      else
        ShowMessageDialog('ERROR DETECTED...');
      Exit;
    end
  end;
end;

procedure TMainForm.TopRedButtonOnClick(Sender: TObject);
var
  P: Integer;
  Returned: String;
begin
  P := Pos('ON', TopRedButton.Text);
  if P > 0 then
  begin
    Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_TOPREDLIGHT_ON) + COMMAND_DELIMITER);
    if Returned = '!;' then TopRedButton.Text := Copy(TopRedButton.Text, 0, P-1) + 'OFF'
    else
      ShowMessageDialog('ERROR DETECTED...');
    Exit;
  end
  else
  begin
    P := Pos('OFF', TopRedButton.Text);
    if P > 0 then
    begin
      Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_TOPREDLIGHT_OFF) + COMMAND_DELIMITER);
      if Returned = '!;' then TopRedButton.Text := Copy(TopRedButton.Text, 0, P-1) + 'ON'
      else
        ShowMessageDialog('ERROR DETECTED...');
      Exit;
    end
  end;
end;

procedure TMainForm.ResetScan;
begin
  ClearBluetoothComponents;
  Scanning := False;
  ConnectButton.Text := CONN_BTN_SCAN;
  AnimatedIndicator.Enabled := False;
  AnimatedIndicator.Visible := False;
  Ready := False;
end;

procedure TMainForm.SetScanning;
begin
  Scanning := True;
  ConnectButton.Text := CONN_BTN_SCANNING;
  AnimatedIndicator.Enabled := True;
  AnimatedIndicator.Visible := True;
  Ready := False;
end;

procedure TMainForm.MainFormOnClose(Sender: TObject; var Action: TCloseAction);
begin
  if DebugEditFocused then
  begin
    DebugEdit.ResetFocus;
    DebugEditFocused := False;
  end;
//  ClearInitialStatesOfLights;
  ClearFormComponents;
  //  Wait For Android
  WaitTimer.OnTimer := WaitTimerOnClose;
  WaitTimer.Interval := 2000;
  WaitTimer.Enabled := True;
end;

procedure TMainForm.MainFormOnKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkHardwareBack then
  begin
    // Do whatever you want to do here
    Key := 0; // Set Key = 0 if you want to prevent the default action
  end;
end;

function TMainForm.ManagerConnected:Boolean;
var
  FManager: TBluetoothManager;
begin
  FManager := TBluetoothManager.Current;
  if Assigned(FManager) and (FManager.ConnectionState = TBluetoothConnectionState.Connected) then
  begin
    FBluetoothManager := FManager;
    FAdapter := FBluetoothManager.CurrentAdapter;
    Result := True;
  end
  else
  begin
    Result := False;
  end
end;

procedure TMainForm.BootomWhiteButtonOnClick(Sender: TObject);
var
  P: Integer;
  Returned: String;
begin
  P := Pos('ON', BottomWhiteButton.Text);
  if P > 0 then
  begin
    Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_BOTTOMWHITELIGHT_ON) + COMMAND_DELIMITER);
    if Returned = '!;' then BottomWhiteButton.Text := Copy(BottomWhiteButton.Text, 0, P-1) + 'OFF'
    else
      ShowMessageDialog('ERROR DETECTED...');
    Exit;
  end
  else
  begin
    P := Pos('OFF', BottomWhiteButton.Text);
    if P > 0 then
    begin
      Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_BOTTOMWHITELIGHT_OFF) + COMMAND_DELIMITER);
      if Returned = '!;' then BottomWhiteButton.Text := Copy(BottomWhiteButton.Text, 0, P-1) + 'ON'
      else
        ShowMessageDialog('ERROR DETECTED...');
      Exit;
    end
  end;
end;

procedure TMainForm.BottomBlackButtonOnClick(Sender: TObject);
var
  P: Integer;
  Returned: String;
begin
  P := Pos('ON', BottomBlackButton.Text);
  if P > 0 then
  begin
    Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_BOTTOMBLACKLIGHT_ON) + COMMAND_DELIMITER);
    if Returned = '!;' then BottomBlackButton.Text := Copy(BottomBlackButton.Text, 0, P-1) + 'OFF'
    else
      ShowMessageDialog('ERROR DETECTED...');
    Exit;
  end
  else
  begin
    P := Pos('OFF', BottomBlackButton.Text);
    if P > 0 then
    begin
      Returned := SendMessageToExposureBox(COMMAND_PREFIX + IntToStr(CMD_BOTTOMBLACKLIGHT_OFF) + COMMAND_DELIMITER);
      if Returned = '!;' then BottomBlackButton.Text := Copy(BottomBlackButton.Text, 0, P-1) + 'ON'
      else
        ShowMessageDialog('ERROR DETECTED...');
      Exit;
    end
  end;
end;

procedure TMainForm.ClearBluetoothComponents;
begin
  if Assigned(ExposureBox) then
  begin
    ExposureBox.Free;
    ExposureBox := nil;
  end;
  if Assigned(FAdapter) then
  begin
    FAdapter.Free;
    FAdapter := nil;
  end;
  if Assigned(FBluetoothManager) then
  begin
    FBluetoothManager.Free;
    FBluetoothManager := nil;
  end;
end;

procedure TMainForm.ShowRetryMessage(const TheMessage: String);
begin
  Sound(50);
  TDialogService.PreferredMode := TDialogService.TPreferredMode.Sync;
  TDialogService.MessageDialog('Bluetooth device not found. Retry ?', System.UITypes.TMsgDlgType.mtInformation,
    [System.UITypes.TMsgDlgBtn.mbYes, System.UITypes.TMsgDlgBtn.mbNo],
    System.UITypes.TMsgDlgBtn.mbYes, 0,
    // Use an anonymous method to make sure the acknowledgment appears as expected.
    procedure(const AResult: TModalResult)
    begin
      case AResult of
        { Detect which button was pushed and show a different message }
        mrYES:
            ConnectButton.Text := CONN_BTN_SCAN;
        mrNo:
            MainForm.Close;
      end;
    end);
end;

function TMainForm.IsBluetoothEnabled: Boolean;
begin
  ClearBluetoothComponents;
  Result := False;
  if ManagerConnected then Result := True
  else
  begin
    ShowRetryMessage('Bluetooth device not found. Retry ?');
  end;
end;

procedure TMainForm.ClearConnectionFlags;
begin
  Scanning := False;
  AnimatedIndicator.Enabled := False;
  AnimatedIndicator.Visible := False;
end;

procedure TMainForm.ConnectButtonOnClick(Sender: TObject);
begin
  ClearFormComponents;
  ClearConnectionFlags;
  if IsBluetoothEnabled then
  begin
    SetScanning;
    StartBluetoothScan;
  end;
end;

procedure TMainForm.Setup;
begin
  ClearFormComponents;
  ClearConnectionFlags;
  if IsBluetoothEnabled then
  begin
    SetScanning;
    StartBluetoothScan;
  end;
end;

procedure TMainForm.WaitTimerOnSetup(Sender: TObject);
begin
  WaitTimer.Enabled := False;
  Setup;
end;

procedure TMainForm.WaitTimerOnClose(Sender: TObject);
begin
  MainForm.Close;
end;

procedure TMainForm.ApplicationCloseButtonOnClick(Sender: TObject);
begin
//  Exposure Box Reset
  ExposureBoxReset;

  if DebugEditFocused then
  begin
    DebugEdit.ResetFocus;
    DebugEditFocused := False;
  end;
  ClearFormComponents;
  //  Wait For Android
  WaitTimer.OnTimer := WaitTimerOnClose;
  WaitTimer.Interval := 2000;
  WaitTimer.Enabled := True;
end;

procedure TMainForm.ClearFormComponents;
begin
  CommonTabControl.Enabled := False;
  CommonTabControl.Visible := False;
  CommonTabControl.ActiveTab := ControlTab;
  DebugEditFocused := False;
  IsIdle := True;
end;

procedure TMainForm.MainFormOnShow(Sender: TObject);
begin
  MainFormSender := Sender;
  ClearFormComponents;
  WaitTimer.Interval := 1000; // 500ms
  WaitTimer.OnTimer := WaitTimerOnSetup;
  WaitTimer.Enabled := True;
end;

end.
