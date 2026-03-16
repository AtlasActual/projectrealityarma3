#include "script_component.hpp"
/*
    FUNC(dismantleAction)

    Description:
        Ten-second hold action for a squad leader to voluntarily dismantle
        a friendly FOB. The player must be the group leader, alive, on
        foot, and within 5 metres of their side's FOB. On completion
        the "fobDismantle" event is fired on the server which removes
        the deployment point and all linked objects.

    Parameters:
        0: _player - the squad leader performing the dismantle (Object)

    Returns: nothing
*/

params [["_player", objNull, [objNull]]];

if (isNull _player || {!alive _player}) exitWith {};
if (vehicle _player != _player) exitWith {};

// Must be the group leader
if (_player != leader group _player) exitWith {
    systemChat "Only the squad leader can dismantle a FOB.";
};

// ======================================================================
// Locate the nearest friendly FOB within 5 metres
// ======================================================================
private _playerSide = side group _player;
private _playerPos  = getPosATL _player;

private _targetPointId = "";

{
    private _entry = _y;
    private _type  = _entry getOrDefault ["type", ""];
    private _avail = _entry getOrDefault ["availableFor", sideUnknown];

    if (_type == "FOB" && {_avail isEqualTo _playerSide}) then {
        private _fobPos = _entry getOrDefault ["position", [0, 0, 0]];
        if (_playerPos distance2D _fobPos < 5) exitWith {
            _targetPointId = _x;
        };
    };
} forEach EGVAR(Deployment,pointStorage);

if (_targetPointId == "") exitWith {
    systemChat "No friendly FOB nearby.";
};

// ======================================================================
// Hold action: 10-second dismantle process
// ======================================================================
private _holdDuration = 10;
private _startTime    = diag_tickTime;

GVAR(dismantleInProgress) = true;

_player playMove "AmovPercMstpSnonWnonDnon";

[{
    params ["_args", "_pfhId"];
    _args params ["_player", "_startTime", "_holdDuration", "_targetPointId"];

    // Abort conditions
    if (!alive _player
        || {vehicle _player != _player}
        || {_player != leader group _player}
        || {!GVAR(dismantleInProgress)}) exitWith {

        GVAR(dismantleInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        systemChat "FOB dismantle cancelled.";
    };

    private _elapsed  = diag_tickTime - _startTime;
    private _progress = _elapsed / _holdDuration;

    private _barLen  = floor (_progress * 20);
    private _barFill = "";
    for "_i" from 1 to _barLen do { _barFill = _barFill + "|"; };
    hintSilent format ["Dismantling FOB [%1] %2%%", _barFill, floor (_progress * 100)];

    if (_elapsed >= _holdDuration) exitWith {
        GVAR(dismantleInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        hintSilent "";

        // Fire the dismantle event on the server
        ["fobDismantle", [_targetPointId]] call PRA3_fw_fireServer;

        systemChat "FOB has been dismantled.";
        diag_log format ["[PRA3 FOB] Dismantle action completed by %1 on '%2'", name _player, _targetPointId];
    };
}, 0.1, [_player, _startTime, _holdDuration, _targetPointId]] call PRA3_fw_addPFH;
