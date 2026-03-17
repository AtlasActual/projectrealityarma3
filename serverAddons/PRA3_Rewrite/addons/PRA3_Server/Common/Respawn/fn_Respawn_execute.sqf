#include "script_component.hpp"
/*
    FUNC(execute)

    Description:
        Respawns a player at the supplied world position. When the player
        is dead the engine respawn timer is forced to zero, the code waits
        for the engine to produce a fresh unit, positions it, and optionally
        marks it as a temporary (invisible / frozen) placeholder. When the
        player is already alive the unit is simply teleported.

        In both cases "playerRespawned" fires locally and "mpRespawned"
        fires globally so that every machine can react.

    Params:
        0: _unit       - OBJECT  - player unit to respawn
        1: _pos        - ARRAY   - target world position [x, y, z]
        2: _asTempUnit - BOOLEAN - (default false) freeze and hide the
                         new unit until it is explicitly revealed later

    Returns:
        OBJECT - the unit that now represents the player (may differ from
                 the input when the player was dead)
*/

params ["_unit", "_pos", ["_asTempUnit", false]];

private _output = _unit;

if (!alive _unit) then {
    // Drop the respawn delay so the engine creates a replacement unit
    // on the very next tick
    setPlayerRespawnTime 0;

    private _previousUnit = _unit;

    // Poll each frame until the engine has swapped in a new, living unit
    [{
        params ["_prev"];
        alive player && {player isNotEqualTo _prev}
    }, {
        params ["_prev", "_targetPos", "_hideUnit"];

        private _freshUnit = player;

        _freshUnit setPosATL _targetPos;

        if (_hideUnit) then {
            _freshUnit enableSimulationGlobal false;
            _freshUnit hideObjectGlobal true;
        };

        // Notify local handlers (UI refresh, loadout application, etc.)
        ["playerRespawned", [_freshUnit, _prev]] call PRA3_fw_fireEvent;

        // Broadcast to every connected machine
        ["mpRespawned", [_freshUnit, _prev]] call PRA3_fw_fireGlobal;

        diag_log format [
            "[PRA3 Respawn] Completed respawn for %1 at %2 (hidden: %3)",
            name _freshUnit,
            _targetPos,
            _hideUnit
        ];

    }, [_previousUnit, _pos, _asTempUnit]] call PRA3_fw_waitUntilExec;

} else {
    // Unit is still alive -- just move it
    _unit setPosATL _pos;

    ["playerRespawned", [_unit, _unit]] call PRA3_fw_fireEvent;
    ["mpRespawned", [_unit, _unit]] call PRA3_fw_fireGlobal;

    diag_log format [
        "[PRA3 Respawn] Teleported %1 to %2",
        name _unit,
        _pos
    ];

    _output = _unit;
};

_output
