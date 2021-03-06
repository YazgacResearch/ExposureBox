unit Common.FMX.VirtualKeyboardService;

(*
uses
  Common.FMX.VirtualKeyboardService;

procedure TForm1.AfterConstruction;
begin
  inherited;
  TVirtualKeyboardService.AddOverrideObject( Edit1 );
end;
*)
interface

uses
  System.Classes,
  System.Generics.Collections,
  FMX.Types,
  FMX.VirtualKeyboard;

type
  TVirtualKeyboardService = class( TComponent, IFMXVirtualKeyboardService )
  private
    FObjects: TList<TFmxObject>;
    FOriginalService: IFMXVirtualKeyboardService;
    constructor Create( AOwner: TComponent );
    class constructor Create;
  protected
    function GetVirtualKeyboardState: TVirtualKeyboardStates;
    function HideVirtualKeyboard: Boolean;
    procedure SetTransientState( Value: Boolean );
    function ShowVirtualKeyboard( const AControl: TFmxObject ): Boolean;
    procedure Notification( AComponent: TComponent; Operation: TOperation ); override;
  public
    class function Current: TVirtualKeyboardService;
    destructor Destroy; override;

    procedure AddOverrideObject( AObject: TFmxObject );
    procedure RemoveOverrideObject( AObject: TFmxObject );
    function IsOverriddenObject( AObject: TFmxObject ): Boolean;
  private
    class var _current: TVirtualKeyboardService;
  end;

implementation

uses
  FMX.Forms,
  FMX.Platform,
  System.SysUtils;

{ TVirtualKeyboardService }

constructor TVirtualKeyboardService.Create( AOwner: TComponent );
begin
  inherited Create( AOwner );

  FObjects := TList<TFmxObject>.Create;

  if TPlatformServices.Current.SupportsPlatformService( IFMXVirtualKeyboardService, FOriginalService ) then
  begin
    TPlatformServices.Current.RemovePlatformService( IFMXVirtualKeyboardService );
    TPlatformServices.Current.AddPlatformService( IFMXVirtualKeyboardService, Self );
  end;
end;

procedure TVirtualKeyboardService.AddOverrideObject( AObject: TFmxObject );
begin
  if Supports( AObject, IVirtualKeyboardControl ) and not FObjects.Contains( AObject ) then
  begin
    FObjects.Add( AObject );
    Self.FreeNotification( AObject );
  end;
end;

class constructor TVirtualKeyboardService.Create;
begin
  TVirtualKeyboardService._current := TVirtualKeyboardService.Create( Application );
end;

class function TVirtualKeyboardService.Current: TVirtualKeyboardService;
begin
  Result := TVirtualKeyboardService._current;
end;

destructor TVirtualKeyboardService.Destroy;
begin
  if Assigned( FOriginalService ) then
  begin
    TPlatformServices.Current.RemovePlatformService( IFMXVirtualKeyboardService );
    TPlatformServices.Current.AddPlatformService( IFMXVirtualKeyboardService, FOriginalService );
  end;
  FObjects.Free;
  inherited;
end;

function TVirtualKeyboardService.GetVirtualKeyboardState: TVirtualKeyboardStates;
begin
  Result := FOriginalService.VirtualKeyboardState;
end;

function TVirtualKeyboardService.HideVirtualKeyboard: Boolean;
begin
  Result := FOriginalService.HideVirtualKeyboard;
end;

function TVirtualKeyboardService.IsOverriddenObject( AObject: TFmxObject ): Boolean;
begin
  Result := FObjects.Contains( AObject );
end;

procedure TVirtualKeyboardService.Notification( AComponent: TComponent; Operation: TOperation );
begin
  inherited;
  if ( Operation = opRemove ) and ( AComponent is TFmxObject ) then
  begin
    RemoveOverrideObject( AComponent as TFmxObject );
  end;
end;

procedure TVirtualKeyboardService.RemoveOverrideObject( AObject: TFmxObject );
begin
  if FObjects.Contains( AObject ) then
  begin
    FObjects.Remove( AObject );
    Self.RemoveFreeNotification( AObject );
  end;
end;

procedure TVirtualKeyboardService.SetTransientState( Value: Boolean );
begin
  FOriginalService.SetTransientState( Value );
end;

function TVirtualKeyboardService.ShowVirtualKeyboard( const AControl: TFmxObject ): Boolean;
begin
  if IsOverriddenObject( AControl ) then
    begin
      HideVirtualKeyboard;
      Result := False;
    end
  else
    Result := FOriginalService.ShowVirtualKeyboard( AControl );
end;

end.

