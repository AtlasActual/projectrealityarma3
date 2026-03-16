#include "script_component.hpp"
/*
    FUNC(doRespawn)

    Description:
        Server-only function that performs the actual vehicle respawn
        sequence. Deletes the old vehicle (if it still exists), waits
        briefly, evaluates the respawn condition, creates a fresh
        vehicle at a safe position near the original spawn point,
        clears its cargo, restores variable name and entity variables,
        and notifies the owning side.

    Arguments:
        0: _oldVehicle       - the previous vehicle instance          (Object)
        1: _vehicleType      - classname to spawn                     (String)
        2: _varName          - vehicleVarName to restore              (String)
        3: _spawnPosition    - original spawn position [x,y,z]         (Array)
        4: _spawnDirection   - original facing direction               (Number)
        5: _respawnCondition - SQF string evaluated as condition       (String)
        6: _respawnCounter   - current respawn iteration count         (Number)

    Returns: nothing
*/

if (!isServer) exitWith {};

params [
    "_oldVehicle",
    "_vehicleType",
    ["_varName", ""],
    "_spawnPosition",
    ["_spawnDirection", 0],
    ["_respawnCondition", "true"],
    ["_respawnCounter", 0]
];

// ======================================================================
// 1. Delete the old vehicle if it still exists
// ======================================================================
if (!isNull _oldVehicle) then {
    // Eject any remaining crew before deletion
    {
        moveOut _x;
    } forEach crew _oldVehicle;

    deleteVehicle _oldVehicle;
};

// ======================================================================
// 2. Short delay before spawning replacement
// ======================================================================
[{
    params [
        "_vehicleType", "_varName", "_spawnPosition",
        "_spawnDirection", "_respawnCondition", "_respawnCounter"
    ];

    // ==================================================================
    // 3. Evaluate respawn condition
    // ==================================================================
    private _conditionMet = call compile _respawnCondition;
    if (!(_conditionMet isEqualTo true)) exitWith {
        diag_log format [
            "[PRA3 VehicleRespawn] Respawn condition failed for '%1' (%2) — aborting.",
            _varName, _vehicleType
        ];
    };

    // ==================================================================
    // 4. Find a safe spawn position
    // ==================================================================
    private _safePos = [_spawnPosition, 0, 15, 5, 0] call PRA3_fw_safePos;
    if (count _safePos < 3) then {
        _safePos = _spawnPosition;
    };

    // ==================================================================
    // 5. Create the new vehicle
    // ==================================================================
    private _newVehicle = createVehicle [_vehicleType, _safePos, [], 0, "CAN_COLLIDE"];
    _newVehicle setPosATL _safePos;
    _newVehicle setDir _spawnDirection;

    // Ensure proper physics settling
    _newVehicle setVelocity [0, 0, 0];

    // ==================================================================
    // 6. Clear all cargo
    // ==================================================================
    clearWeaponCargoGlobal _newVehicle;
    clearMagazineCargoGlobal _newVehicle;
    clearItemCargoGlobal _newVehicle;
    clearBackpackCargoGlobal _newVehicle;

    // ==================================================================
    // 7. Restore vehicle variable name
    // ==================================================================
    if (_varName isNotEqualTo "") then {
        _newVehicle setVehicleVarName _varName;
        missionNamespace setVariable [_varName, _newVehicle, true];
    };

    // ==================================================================
    // 8. Copy entity variables to the new vehicle
    // ==================================================================
    private _newCounter = _respawnCounter + 1;
    _newVehicle setVariable ["respawnCounter", _newCounter, true];
    _newVehicle setVariable ["respawnCondition", _respawnCondition, true];

    // Retrieve side from old vehicle data or infer from spawn context
    private _vehSide = sideUnknown;

    // Try to find the side from the original tracked data
    {
        if ((_x get "varName") isEqualTo _varName && {_varName isNotEqualTo ""}) exitWith {
            _vehSide = _x get "side";
        };
    } forEach GVAR(trackedVehicles);

    // If not found from tracking, check if old vehicle had side stored
    if (_vehSide isEqualTo sideUnknown) then {
        // Default to the logic group side if available
        private _logicGrp = call PRA3_fw_getLogicGroup;
        if (!isNull _logicGrp) then {
            _vehSide = side _logicGrp;
        };
    };

    _newVehicle setVariable ["side", _vehSide, true];

    // Preserve the respawn time so the new vehicle can also respawn
    private _origRespawnTime = -1;
    {
        if ((_x get "type") isEqualTo _vehicleType) exitWith {
            _origRespawnTime = _x get "respawnTime";
        };
    } forEach GVAR(trackedVehicles);

    // Fallback: check if there's a default respawn time in config
    if (_origRespawnTime < 0) then {
        _origRespawnTime = getNumber (
            missionConfigFile >> "PRA3" >> "VehicleRespawn" >> "defaultRespawnTime"
        );
        if (_origRespawnTime <= 0) then { _origRespawnTime = 300 };
    };

    _newVehicle setVariable ["respawnTime", _origRespawnTime, true];

    // ==================================================================
    // 9. Register the new vehicle in the tracking system
    // ==================================================================
    [_newVehicle] call FUNC(registerVehicle);

    // ==================================================================
    // 10. Notify the owning side
    // ==================================================================
    private _displayName = getText (
        configFile >> "CfgVehicles" >> _vehicleType >> "displayName"
    );

    if !(_vehSide isEqualTo sideUnknown) then {
        ["vehicleAvailable", [_displayName]] call PRA3_fw_fireTarget;
    };

    diag_log format [
        "[PRA3 VehicleRespawn] Respawned '%1' (%2) at %3 — iteration #%4",
        _varName, _vehicleType, _safePos, _newCounter
    ];

}, 3, [
    _vehicleType, _varName, _spawnPosition,
    _spawnDirection, _respawnCondition, _respawnCounter
]] call PRA3_fw_waitAndExec;
