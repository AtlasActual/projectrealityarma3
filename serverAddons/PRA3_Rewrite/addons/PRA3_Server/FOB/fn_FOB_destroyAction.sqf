#include "script_component.hpp"
/*
    FUNC(destroyAction)

    Description:
        Five-second hold action to initiate the destruction countdown on
        an enemy FOB. The player must be within 5 metres of an enemy FOB
        object and remain alive and on foot for the full duration. On
        completion, fires the "fobDestroyStart" event on the server with
        the target FOB's deployment point ID.

    Parameters:
        0: _player - the unit performing the action (Object)

    Returns: nothing
*/

params [["_player", objNull, [objNull]]];

if (isNull _player || {!alive _player}) exitWith {};
if (vehicle _player != _player) exitWith {};

// ======================================================================
// Locate the nearest enemy FOB deployment point within 5 metres
// ======================================================================
private _playerSide = side group _player;
private _playerPos  = getPosATL _player;

private _targetPointId = "";

{
    private _entry = _y;
    private _type  = _entry getOrDefault ["type", ""];
    private _avail = _entry getOrDefault ["availableFor", sideUnknown];

    if (_type == "FOB" && {!(_avail isEqualTo _playerSide)}) then {
        private _fobPos = _entry getOrDefault ["position", [0, 0, 0]];
        if (_playerPos distance2D _fobPos < 5) exitWith {
            _targetPointId = _x;
        };
    };
} forEach EGVAR(Deployment,pointStorage);

if (_targetPointId == "") exitWith {
    systemChat "No enemy FOB nearby.";
};

// ======================================================================
// Hold action: 5-second destruction initiation
// ======================================================================
private _holdDuration = 5;
private _startTime    = diag_tickTime;

GVAR(destroyInProgress) = true;
GVAR(destroyTargetId)   = _targetPointId;

_player playMove "AmovPercMstpSnonWnonDnon";

[{
    params ["_args", "_pfhId"];
    _args params ["_player", "_startTime", "_holdDuration", "_targetPointId"];

    // Abort conditions
    if (!alive _player
        || {vehicle _player != _player}
        || {!GVAR(destroyInProgress)}) exitWith {

        GVAR(destroyInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        systemChat "FOB destruction cancelled.";
    };

    private _elapsed  = diag_tickTime - _startTime;
    private _progress = _elapsed / _holdDuration;

    private _barLen  = floor (_progress * 20);
    private _barFill = "";
    for "_i" from 1 to _barLen do { _barFill = _barFill + "|"; };
    hintSilent format ["Planting explosives [%1] %2%%", _barFill, floor (_progress * 100)];

    if (_elapsed >= _holdDuration) exitWith {
        GVAR(destroyInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        hintSilent "";

        // Fire the destroy event on the server
        ["fobDestroyStart", [_targetPointId]] call PRA3_fw_fireServer;

        systemChat "Explosives planted on enemy FOB!";
        diag_log format ["[PRA3 FOB] Destroy action completed by %1 on '%2'", name _player, _targetPointId];
    };
}, 0.1, [_player, _startTime, _holdDuration, _targetPointId]] call PRA3_fw_addPFH;
