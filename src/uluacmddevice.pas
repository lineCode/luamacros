unit uLuaCmdDevice;

{$mode delphi}

interface

uses
  Classes, SysUtils, Lua;

function PrintDevices(luaState : TLuaState) : integer;
function GetDevices(luaState : TLuaState) : integer;
function CheckDeviceNameWithAsk(luaState : TLuaState) : integer;
function AssignDeviceNameByRegexp(luaState : TLuaState) : integer;
function LuaCmdSetCallback(luaState : TLuaState) : integer;
function AddCom(luaState : TLuaState) : integer;
function SetComSplitter(luaState : TLuaState) : integer;
function SendCom(luaState : TLuaState) : integer;

implementation

uses
  uGlobals, uDevice;

function PrintDevices(luaState : TLuaState) : integer;
var lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_print_devices');
     Glb.DeviceService.ListDevices;
     Result := 0;
     Glb.StatsService.EndCommand('lmc_print_devices', lStart);
end;

function GetDevices(luaState: TLuaState): integer;
var
  lItem: TDevice;
  lI: Integer;
  lName: String;
  lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_get_devices');
  lua_createtable(luaState, 0, Glb.DeviceService.Devices.Count);
  for lI := 0 to Glb.DeviceService.Devices.Count - 1 do
  begin
    lItem := Glb.DeviceService.Devices[lI];
    if (lItem.Name = '') then
      lName := cUnassigned
    else
      lName := lItem.Name;
    //Result.Add(Format('%s:%s:%s', [lName, lItem.SystemId, lItem.TypeCaption]));
    // lName, lItem.SystemId, lItem.Handle, lItem.TypeCaption
    lua_createtable(luaState, 0, 4);
    lua_pushstring(luaState, 'Name');
    lua_pushstring(luaState, PChar(lName));
    lua_rawset(luaState, -3);

    lua_pushstring(luaState, 'SystemId');
    lua_pushstring(luaState, PChar(lItem.SystemId));
    lua_rawset(luaState, -3);

    lua_pushstring(luaState, 'Handle');
    lua_pushnumber(luaState, lItem.Handle);
    lua_rawset(luaState, -3);

    lua_pushstring(luaState, 'Type');
    lua_pushstring(luaState, PChar(lItem.TypeCaption));
    lua_rawset(luaState, -3);

    lua_rawseti(luaState, -2, lI);
  end;
  Result := 1;
  Glb.StatsService.EndCommand('lmc_get_devices', lStart);
end;

function CheckDeviceNameWithAsk(luaState : TLuaState) : integer;
var arg : PAnsiChar;
  lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_assign_keyboard');
     //reads the first parameter passed to Increment as an integer
     arg := lua_tostring(luaState, 1);

     //print
     Glb.DeviceService.CheckNameAsk(arg);

     //clears current Lua stack
     Lua_Pop(luaState, Lua_GetTop(luaState));

     //Result : number of results to give back to Lua
     Result := 0;
     Glb.StatsService.EndCommand('lmc_assign_keyboard', lStart);
end;

function AssignDeviceNameByRegexp(luaState: TLuaState): integer;
var
  lName : PAnsiChar;
  lRegexp : PAnsiChar;
  lResult : String;
  lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_device_set_name');
  lName := lua_tostring(luaState, 1);
  lRegExp := lua_tostring(luaState, 2);
  lResult := Glb.DeviceService.AssignNameByRegexp(lName, lRegexp);
  lua_pushstring(luaState, PChar(lResult));
  Result := 1;
  Glb.StatsService.EndCommand('lmc_device_set_name', lStart);
end;

function LuaCmdSetCallback(luaState: TLuaState): integer;
var
  lDeviceName : PAnsiChar;
  lButton : Integer;
  lDirection : Integer;
  lHandlerRef: Integer;
  lNumOfParams: Integer;
  lButtonStr: String;
  lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_set_handler');
  // Device name
  // Button number
  // 1 = down, 0 = up
  // handler
  lNumOfParams:=lua_gettop(luaState);
  lDeviceName := lua_tostring(luaState, 1);
  if (lNumOfParams = 4) then
  begin
    if lua_isnumber(luaState, 2) = 1 then
      lButton:= Trunc(lua_tonumber(luaState, 2))
    else if lua_isstring(luaState, 2) = 1 then
    begin
      lButtonStr := lua_tostring(luaState, 2);
      if (Length(lButtonStr) <> 1) then
        raise LmcException.Create('Wrong length of 2nd parameter. It must be 1 char');
      lButton:=Ord(lButtonStr[1]);
    end else
      raise LmcException.Create('Wrong type of 2nd parameter. Provide int or char.');
    lDirection:= Trunc(lua_tonumber(luaState, 3));
    if (lDirection <> cDirectionUp) then
      lDirection:=cDirectionDown;
    lHandlerRef := luaL_ref(luaState, LUA_REGISTRYINDEX);
    Glb.LuaEngine.SetCallback(lDeviceName,lButton, lDirection, lHandlerRef);
  end;
  if (lNumOfParams = 2) then
  begin
    // whole device
    lHandlerRef := luaL_ref(luaState, LUA_REGISTRYINDEX);
    Glb.LuaEngine.SetDeviceCallback(lDeviceName, lHandlerRef);
  end;
  Result := 0;
  Glb.StatsService.EndCommand('lmc_set_handler', lStart);
end;

function AddCom(luaState: TLuaState): integer;
var
  lDevName : PAnsiChar;
  lComName : PAnsiChar;
  lNumOfParams : Integer;
  lSpeed: Integer;
  lParity: String;
  lDataBits: Integer;
  lStopBits: Integer;
  lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_add_com');
  lNumOfParams:=lua_gettop(luaState);
  lDevName := lua_tostring(luaState, 1);
  lComName := lua_tostring(luaState, 2);
  if (lNumOfParams = 6) then
  begin
    lSpeed := lua_tointeger(luaState, 3);
    lDataBits:=lua_tointeger(luaState, 4);
    lParity:=lua_tostring(luaState, 5);
    lStopBits:=lua_tointeger(luaState, 6);
    Glb.DeviceService.AddCom(lDevName, lComName, lSpeed, lDataBits, lParity, lStopBits);
  end
  else
    Glb.DeviceService.AddCom(lDevName, lComName);
  Result := 0;
  Glb.StatsService.EndCommand('lmc_add_com', lStart);
end;

function SetComSplitter(luaState: TLuaState): integer;
var
  lName : PAnsiChar;
  lSplitter : PAnsiChar;
  lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_set_com_splitter');
  lName := lua_tostring(luaState, 1);
  lSplitter := lua_tostring(luaState, 2);
  Glb.DeviceService.SetComSplitter(lName, lSplitter);
  Result := 0;
  Glb.StatsService.EndCommand('lmc_set_com_splitter', lStart);
end;

function SendCom(luaState: TLuaState): integer;
var
  lDevName : PAnsiChar;
  lData : PAnsiChar;
  lStart: Int64;
begin
  lStart := Glb.StatsService.BeginCommand('lmc_send_to_com');
  lDevName := lua_tostring(luaState, 1);
  lData := lua_tostring(luaState, 2);
  Glb.DeviceService.SendToCom(lDevName, lData);
  Result := 0;
  Glb.StatsService.EndCommand('lmc_send_to_com', lStart);
end;


end.

