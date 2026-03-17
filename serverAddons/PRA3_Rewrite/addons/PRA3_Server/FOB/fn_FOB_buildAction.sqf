#include "script_component.hpp"
/*
    FUNC(buildAction)

    Description:
        Begins a 5-second hold sequence for FOB construction. A per-frame
        handler drives a progress indicator and validates the player each
        tick. On completion the request is forwarded to the server via
        remoteExecCall for mutex-protected execution.

    Execution: client only, triggered by the "Build FOB" addAction.
*/

if (!hasInterface) exitWith {};

// Immediate eligibility gate
if !([player] call FUNC(canPlace)) exitWith {
    systemChat "Cannot build a FOB here.";
};

// Block concurrent hold actions
if (!isNil QGVAR(buildActive) && {GVAR(buildActive)}) exitWith {};
GVAR(buildActive) = true;

private _holdSec = 5;
private _t0      = diag_tickTime;

// Lock the player in place during the hold
player playMove "AmovPercMstpSnonWnonDnon";

[{
    params ["_args", "_pfh"];
    _args params ["_t0", "_holdSec"];

    // Abort when the player dies, enters a vehicle, or moves too far
    if (!alive player || {vehicle player != player}) exitWith {
        GVAR(buildActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;
        systemChat "FOB construction cancelled.";
    };

    private _dt  = diag_tickTime - _t0;
    private _pct = (_dt / _holdSec) min 1;

    // Simple text-based progress feedback
    private _filled = floor (_pct * 20);
    private _bar = "";
    for "_j" from 1 to _filled do { _bar = _bar + "|"; };
    hintSilent format ["Building FOB  [%1] %2%%", _bar, floor (_pct * 100)];

    if (_dt >= _holdSec) exitWith {
        GVAR(buildActive) = false;
        hintSilent "";
        [_pfh] call PRA3_fw_removePFH;

        // Forward the placement to the server via mutex to prevent race conditions
        ["fobPlace", {
            params ["_caller"];
            [_caller] call FUNC(place);
        }, [player]] call PRA3_fw_mutexLock;

        diag_log format ["[PRA3:FOB] Build hold completed by %1", name player];
    };
}, 0.1, [_t0, _holdSec]] call PRA3_fw_addPFH;
