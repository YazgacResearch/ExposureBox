unit Tools;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
{$IFDEF ANDROID}
  Androidapi.JNIBridge,
  AndroidApi.JNI.Media,
{$ENDIF}
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation;

function ShowMessageDialog(const TheMessage: String): TMsgDlgBtn;

{$IFDEF ANDROID}
  procedure Sound(ADuration: Integer);
{$ENDIF}

implementation

uses FMX.DialogService;


procedure Sound(ADuration: Integer);
//  STREAM_VOICE_CALL (0)
//  STREAM_SYSTEM (1)
//  STREAM_RING (2)
//  STREAM_MUSIC(3)
//  STREAM_ALARM(4)
var
  Volume: Integer;
  StreamType: Integer;
  ToneType: Integer;
  ToneGenerator: JToneGenerator;
begin

  Volume := TJToneGenerator.JavaClass.MAX_VOLUME;

  StreamType := 1;
  ToneType := TJToneGenerator.JavaClass.TONE_DTMF_0;

  ToneGenerator := TJToneGenerator.JavaClass.init(StreamType, Volume);
  ToneGenerator.startTone(ToneType, ADuration);

end;

function ShowMessageDialog(const TheMessage: String): TMsgDlgBtn;
var
  ButtonSelected: TMsgDlgBtn;
begin
  TDialogService.PreferredMode := TDialogService.TPreferredMode.Sync;
  TDialogService.MessageDialog(TheMessage, System.UITypes.TMsgDlgType.mtInformation,
    [System.UITypes.TMsgDlgBtn.mbOk],
    System.UITypes.TMsgDlgBtn.mbOk, 0,
    // Use an anonymous method to make sure the acknowledgment appears as expected.
    procedure(const AResult: TModalResult)
    begin
      case AResult of
        { Detect which button was pushed and show a different message }
        mrOk: ButtonSelected := System.UITypes.TMsgDlgBtn.mbOk;
      else
        ButtonSelected := System.UITypes.TMsgDlgBtn.mbIgnore;
      end;
    end);
  Result := ButtonSelected;
end;

end.
