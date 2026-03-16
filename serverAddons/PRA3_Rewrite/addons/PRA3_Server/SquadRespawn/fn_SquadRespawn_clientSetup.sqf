#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side squad mobile spawn point monitor. Runs a periodic
        check (every 2 seconds) on the player's group members. Any
        member flagged with "hasRespawnPointAttached" = true becomes
        a mobile deployment point of type "SQUAD" available only to
        the player's group. Points are created, updated (position),
        and removed as squad members move, die, or leave the group.

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// Active squad spawn points: unitUID -> deployPointId
GVAR(activePoints) = createHashMap;

// ======================================================================
// Per-frame handler: check squad members every 2 seconds
// ======================================================================
[{
    if (isNull player) exitWith {};

    private _playerGrp  = group player;
    private _playerSide = side group player;
    private _members    = units _playerGrp;

    // Track which unit UIDs are still valid this tick
    private _currentValid = createHashMap;

    {
        private _unit = _x;
        if (isNull _unit) then { continue };

        private _uid = getPlayerUID _unit;
        if (_uid isEqualTo "") then {
            // AI units: use object identity string instead
            _uid = str _unit;
        };

        private _hasSpawn = _unit getVariable ["hasRespawnPointAttached", false];
        private _isAlive  = alive _unit;
        private _unitPos  = getPosATL _unit;

        if (_hasSpawn && _isAlive) then {
            _currentValid set [_uid, true];

            private _existingPid = GVAR(activePoints) getOrDefault [_uid, ""];

            if (_existingPid isEqualTo "") then {
                // Create a new deployment point for this squad member
                private _pointId = [
                    format ["Squad Rally (%1)", name _unit],
                    "SQUAD",
                    _unitPos,
                    _playerGrp,
                    -1,
                    "iconManLeader",
                    "mil_join",
                    [],
                    createHashMap
                ] call EFUNC(Deployment,addPoint);

                GVAR(activePoints) set [_uid, _pointId];

                diag_log format [
                    "[PRA3 SquadRespawn] Created spawn point '%1' on %2",
                    _pointId, name _unit
                ];
            } else {
                // Update position of existing deployment point
                [_existingPid, "position", _unitPos] call EFUNC(Deployment,setData);
            };
        };
    } forEach _members;

    // Remove points for units that are dead, left group, or lost the flag
    private _toRemove = [];
    {
        private _uid = _x;
        private _pid = _y;

        if !(_uid in _currentValid) then {
            _toRemove pushBack _uid;

            // Remove the deployment point from the registry
            [_pid] call EFUNC(Deployment,removePoint);

            diag_log format [
                "[PRA3 SquadRespawn] Removed spawn point '%1' (unit gone/dead/left)",
                _pid
            ];
        };
    } forEach GVAR(activePoints);

    {
        GVAR(activePoints) deleteAt _x;
    } forEach _toRemove;

}, 2, []] call PRA3_fw_addPFH;

// ======================================================================
// Handle group change: clean up all existing points immediately
// ======================================================================
["groupChanged", {
    {
        [_y] call EFUNC(Deployment,removePoint);
    } forEach GVAR(activePoints);

    GVAR(activePoints) = createHashMap;

    diag_log "[PRA3 SquadRespawn] Group changed — all squad spawn points cleared.";
}] call PRA3_fw_addHandler;

diag_log "[PRA3 SquadRespawn] Client squad respawn monitor active.";
