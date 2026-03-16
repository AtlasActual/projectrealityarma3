#include "script_component.hpp"
/*
    FUNC(destroyAction)

    Description:
        5-second hold action that arms the destruction sequence on a
        nearby enemy FOB. The player must be alive, on foot, and within
        5 m of an enemy FOB object. Upon completion the "fobTimerStart"
        event is fired on the server with the targeted deployment-point
        ID.

    Execution: client only.
*/

if (!hasInterface) exitWith {};
if (vehicle player != player) exitWith {};

private _mySide = side group player;
private _myPos  = getPosATL player;

// ======================================================================
// Scan for the closest enemy FOB within 5 m
// ======================================================================
private _foundId = "";

{
    private _rec = _y;
    if (_rec getOrDefault ["type", ""] == "FOB") then {
        private _owner = _rec getOrDefault ["availableFor", sideUnknown];
        if !(_owner isEqualTo _mySide) then {
            if (_myPos distance2D (_rec getOrDefault ["position", [0,0,0]]) < 5) exitWith {
                _foundId = _x;
            };
        };
    };
} forEach EGVAR(Deployment,pointStorage);

if (_foundId == "") exitWith { systemChat "No enemy FOB in range."; };

// Block concurrent holds
if (!isNil QGVAR(demolishActive) && {GVAR(demolishActive)}) exitWith {};
GVAR(demolishActive) = true;

private _holdSec = 5;
private _t0      = diag_tickTime;

player playMove "AmovPercMstpSnonWnonDnon";

[{
    params ["_args", "_pfh"];
    _args params ["_t0", "_holdSec", "_ptId"];

    if (!alive player || {vehicle player != player}) exitWith {
        GVAR(demolishActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;
        systemChat "Demolition aborted.";
    };

    private _dt  = diag_tickTime - _t0;
    private _pct = (_dt / _holdSec) min 1;

    private _filled = floor (_pct * 20);
    private _bar = "";
    for "_j" from 1 to _filled do { _bar = _bar + "|"; };
    hintSilent format ["Planting charge  [%1] %2%%", _bar, floor (_pct * 100)];

    if (_dt >= _holdSec) exitWith {
        GVAR(demolishActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;

        ["fobTimerStart", [_ptId]] call PRA3_fw_fireServer;
        systemChat "Explosives set on enemy FOB!";
        diag_log format ["[PRA3:FOB] Destroy hold completed by %1 on '%2'", name player, _ptId];
    };
}, 0.1, [_t0, _holdSec, _foundId]] call PRA3_fw_addPFH;
