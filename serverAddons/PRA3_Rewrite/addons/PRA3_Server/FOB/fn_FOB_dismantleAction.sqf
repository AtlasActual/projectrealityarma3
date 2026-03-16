#include "script_component.hpp"
/*
    FUNC(dismantleAction)

    Description:
        10-second hold action for voluntarily removing a friendly FOB.
        The player must be alive, on foot, and within 5 m of their own
        FOB. On completion the deployment point is removed on the server
        via EFUNC(Deployment,removePoint).

    Execution: client only.
*/

if (!hasInterface) exitWith {};
if (vehicle player != player) exitWith {};

private _mySide = side group player;
private _myPos  = getPosATL player;

// ======================================================================
// Locate the nearest own-side FOB within 5 m
// ======================================================================
private _foundId = "";

{
    private _rec = _y;
    if (_rec getOrDefault ["type", ""] == "FOB") then {
        private _owner = _rec getOrDefault ["availableFor", sideUnknown];
        if (_owner isEqualTo _mySide) then {
            if (_myPos distance2D (_rec getOrDefault ["position", [0,0,0]]) < 5) exitWith {
                _foundId = _x;
            };
        };
    };
} forEach EGVAR(Deployment,pointStorage);

if (_foundId == "") exitWith { systemChat "No friendly FOB nearby."; };

// Block concurrent holds
if (!isNil QGVAR(dismantleActive) && {GVAR(dismantleActive)}) exitWith {};
GVAR(dismantleActive) = true;

private _holdSec = 10;
private _t0      = diag_tickTime;

player playMove "AmovPercMstpSnonWnonDnon";

[{
    params ["_args", "_pfh"];
    _args params ["_t0", "_holdSec", "_ptId"];

    if (!alive player || {vehicle player != player}) exitWith {
        GVAR(dismantleActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;
        systemChat "Dismantle cancelled.";
    };

    private _dt  = diag_tickTime - _t0;
    private _pct = (_dt / _holdSec) min 1;

    private _filled = floor (_pct * 20);
    private _bar = "";
    for "_j" from 1 to _filled do { _bar = _bar + "|"; };
    hintSilent format ["Dismantling FOB  [%1] %2%%", _bar, floor (_pct * 100)];

    if (_dt >= _holdSec) exitWith {
        GVAR(dismantleActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;

        // Ask the server to remove the deployment point
        [_ptId] remoteExecCall [QEFUNC(Deployment,removePoint), 2];
        systemChat "FOB dismantled.";
        diag_log format ["[PRA3:FOB] Dismantle hold completed by %1 on '%2'", name player, _ptId];
    };
}, 0.1, [_t0, _holdSec, _foundId]] call PRA3_fw_addPFH;
