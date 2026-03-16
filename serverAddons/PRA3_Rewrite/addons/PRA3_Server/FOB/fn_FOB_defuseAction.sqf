#include "script_component.hpp"
/*
    FUNC(defuseAction)

    Description:
        Five-second hold action to defuse (reset) the destruction timer
        on a friendly FOB that is currently under attack. The player must
        be alive, on foot, and within 5 metres of the FOB. On completion
        the "fobTimerReset" event is fired on the server, cancelling the
        destruction countdown.

    Parameters:
        0: _player - the unit performing the defusal (Object)

    Returns: nothing
*/

params [["_player", objNull, [objNull]]];

if (isNull _player || {!alive _player}) exitWith {};
if (vehicle _player != _player) exitWith {};

// ======================================================================
// Locate the nearest friendly FOB that has an active destruction timer
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

// Verify this FOB actually has an active destruction timer
// The timer data is stored server-side, but we can check via custom data
// or rely on the server to validate. Fire regardless and let the server
// handle the no-op case if no timer exists.

// ======================================================================
// Hold action: 5-second defusal process
// ======================================================================
private _holdDuration = 5;
private _startTime    = diag_tickTime;

GVAR(defuseInProgress) = true;

_player playMove "AmovPercMstpSnonWnonDnon";

[{
    params ["_args", "_pfhId"];
    _args params ["_player", "_startTime", "_holdDuration", "_targetPointId"];

    // Abort conditions
    if (!alive _player
        || {vehicle _player != _player}
        || {!GVAR(defuseInProgress)}) exitWith {

        GVAR(defuseInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        systemChat "Defusal cancelled.";
    };

    private _elapsed  = diag_tickTime - _startTime;
    private _progress = _elapsed / _holdDuration;

    private _barLen  = floor (_progress * 20);
    private _barFill = "";
    for "_i" from 1 to _barLen do { _barFill = _barFill + "|"; };
    hintSilent format ["Defusing FOB [%1] %2%%", _barFill, floor (_progress * 100)];

    if (_elapsed >= _holdDuration) exitWith {
        GVAR(defuseInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        hintSilent "";

        // Fire the reset event on the server to cancel the destruction
        ["fobTimerReset", [_targetPointId]] call PRA3_fw_fireServer;

        systemChat "FOB explosives defused!";
        diag_log format ["[PRA3 FOB] Defuse action completed by %1 on '%2'", name _player, _targetPointId];
    };
}, 0.1, [_player, _startTime, _holdDuration, _targetPointId]] call PRA3_fw_addPFH;
