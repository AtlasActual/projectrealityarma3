#include "script_component.hpp"
/*
    FUNC(buildAction)

    Description:
        Five-second hold action for placing a FOB. The player must pass
        the canPlace check and remain on foot near the FOB supply box.
        The canPlace result is cached and refreshed every two seconds
        for performance. On successful completion the placement request
        is forwarded to the server via mutex-protected remoteExecCall.

    Parameters:
        0: _player - the unit performing the action (Object)

    Returns: nothing
*/

params [["_player", objNull, [objNull]]];

if (isNull _player || {!alive _player}) exitWith {};

// Re-validate with the cached canPlace check
if !(call FUNC(canPlaceCached)) exitWith {
    systemChat "Cannot place FOB here.";
};

// Verify the player is near a FOB supply box of their side
private _playerSide = side group _player;
private _boxClass   = GVAR(sideBoxMap) getOrDefault [_playerSide, ""];
private _playerPos  = getPosATL _player;

private _nearBox = false;
if (_boxClass != "") then {
    private _nearObjects = nearestObjects [_playerPos, [_boxClass], 10];
    _nearBox = count _nearObjects > 0;
};

if (!_nearBox) exitWith {
    systemChat "You must be near a FOB supply box.";
};

// ======================================================================
// Hold action: 5-second progress bar
// ======================================================================
private _holdDuration = 5;
private _startTime    = diag_tickTime;

GVAR(buildInProgress) = true;

// Disable player movement during the hold
_player playMove "AmovPercMstpSnonWnonDnon";

// Progress check PFH
[{
    params ["_args", "_pfhId"];
    _args params ["_player", "_startTime", "_holdDuration"];

    // Abort conditions
    if (!alive _player
        || {vehicle _player != _player}
        || {!GVAR(buildInProgress)}) exitWith {

        GVAR(buildInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        systemChat "FOB construction cancelled.";
    };

    private _elapsed  = diag_tickTime - _startTime;
    private _progress = _elapsed / _holdDuration;

    // Display progress feedback
    private _barLen   = floor (_progress * 20);
    private _barFill  = "";
    for "_i" from 1 to _barLen do { _barFill = _barFill + "|"; };
    hintSilent format ["Building FOB [%1] %2%%", _barFill, floor (_progress * 100)];

    // Completion
    if (_elapsed >= _holdDuration) exitWith {
        GVAR(buildInProgress) = false;
        [_pfhId] call PRA3_fw_removePFH;
        hintSilent "";

        // Send placement request to the server under the respawn mutex
        ["respawn", FUNC(place), [_player], _player] call PRA3_fw_mutexLock;

        diag_log format ["[PRA3 FOB] Build action completed by %1", name _player];
    };
}, 0.1, [_player, _startTime, _holdDuration]] call PRA3_fw_addPFH;
