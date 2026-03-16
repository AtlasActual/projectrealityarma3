#include "script_component.hpp"
/*
    FUNC(defuseAction)

    Description:
        5-second hold action that resets the destruction timer on a
        friendly FOB currently under attack. The player must be alive,
        on foot, and within 5 m of the FOB. On completion the
        "fobTimerReset" event is sent to the server, which cancels
        the countdown entirely.

    Execution: client only.
*/

if (!hasInterface) exitWith {};
if (vehicle player != player) exitWith {};

private _mySide = side group player;
private _myPos  = getPosATL player;

// ======================================================================
// Find the nearest friendly FOB within 5 m that has an active timer
// ======================================================================
private _foundId = "";

{
    private _rec = _y;
    if (_rec getOrDefault ["type", ""] == "FOB") then {
        private _owner = _rec getOrDefault ["availableFor", sideUnknown];
        if (_owner isEqualTo _mySide) then {
            if (_myPos distance2D (_rec getOrDefault ["position", [0,0,0]]) < 5) exitWith {
                // Accept it — the server will no-op if there is no timer
                _foundId = _x;
            };
        };
    };
} forEach EGVAR(Deployment,pointStorage);

if (_foundId == "") exitWith { systemChat "No friendly FOB under threat nearby."; };

// Block concurrent holds
if (!isNil QGVAR(defuseActive) && {GVAR(defuseActive)}) exitWith {};
GVAR(defuseActive) = true;

private _holdSec = 5;
private _t0      = diag_tickTime;

player playMove "AmovPercMstpSnonWnonDnon";

[{
    params ["_args", "_pfh"];
    _args params ["_t0", "_holdSec", "_ptId"];

    if (!alive player || {vehicle player != player}) exitWith {
        GVAR(defuseActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;
        systemChat "Defusal interrupted.";
    };

    private _dt  = diag_tickTime - _t0;
    private _pct = (_dt / _holdSec) min 1;

    private _filled = floor (_pct * 20);
    private _bar = "";
    for "_j" from 1 to _filled do { _bar = _bar + "|"; };
    hintSilent format ["Defusing  [%1] %2%%", _bar, floor (_pct * 100)];

    if (_dt >= _holdSec) exitWith {
        GVAR(defuseActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;

        ["fobTimerReset", [_ptId]] call PRA3_fw_fireServer;
        systemChat "FOB charge defused!";
        diag_log format ["[PRA3:FOB] Defuse hold completed by %1 on '%2'", name player, _ptId];
    };
}, 0.1, [_t0, _holdSec, _foundId]] call PRA3_fw_addPFH;
