#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Description:
        Server-side vehicle respawn and abandoned vehicle management.
        Tracks all vehicles that have a "respawnTime" variable >= 0,
        stores their spawn position/direction, handles killed events to
        schedule respawns, and runs an abandoned vehicle state machine
        that reclaims vehicles left far from their spawn with no crew
        or nearby players.

    Called once on the server during module init.
*/

if (!isServer) exitWith {};

// ======================================================================
// 1. Configuration
// ======================================================================
GVAR(trackedVehicles)       = [];      // array of tracked vehicle hashmaps
GVAR(abandonedVehicleRadius) = 100;    // metres from spawn = "abandoned zone"
GVAR(abandonedVehicleTime)   = 600;    // seconds before abandoned vehicle respawns

// ======================================================================
// 2. Helper: register a vehicle for tracking
// ======================================================================
DFUNC(registerVehicle) = {
    params ["_vehicle"];

    private _respawnTime = _vehicle getVariable ["respawnTime", -1];
    if (_respawnTime < 0) exitWith {};

    private _spawnPos  = getPosATL _vehicle;
    private _spawnDir  = getDir _vehicle;
    private _vehType   = typeOf _vehicle;
    private _varName   = vehicleVarName _vehicle;
    private _vehSide   = _vehicle getVariable ["side", sideUnknown];
    private _condition  = _vehicle getVariable ["respawnCondition", "true"];
    private _counter    = _vehicle getVariable ["respawnCounter", 1];

    private _entry = createHashMap;
    _entry set ["vehicle",          _vehicle];
    _entry set ["type",             _vehType];
    _entry set ["spawnPosition",    _spawnPos];
    _entry set ["spawnDirection",   _spawnDir];
    _entry set ["varName",          _varName];
    _entry set ["respawnTime",      _respawnTime];
    _entry set ["side",             _vehSide];
    _entry set ["respawnCondition", _condition];
    _entry set ["respawnCounter",   _counter];
    _entry set ["abandonTimer",     -1];

    GVAR(trackedVehicles) pushBack _entry;

    // Add killed event handler to the vehicle
    _vehicle addEventHandler ["Killed", {
        params ["_veh"];
        private _entryIdx = GVAR(trackedVehicles) findIf {
            (_x get "vehicle") isEqualTo _veh
        };
        if (_entryIdx < 0) exitWith {};

        private _entry = GVAR(trackedVehicles) select _entryIdx;
        private _delay = _entry get "respawnTime";

        diag_log format [
            "[PRA3 VehicleRespawn] Vehicle '%1' (%2) killed — respawn in %3s",
            _entry get "varName", _entry get "type", _delay
        ];

        // Remove from tracked list (will be re-added on respawn)
        GVAR(trackedVehicles) deleteAt _entryIdx;

        // Schedule respawn after delay
        [{
            _this call FUNC(doRespawn);
        }, _delay, [
            _veh,
            _entry get "type",
            _entry get "varName",
            _entry get "spawnPosition",
            _entry get "spawnDirection",
            _entry get "respawnCondition",
            _entry get "respawnCounter"
        ]] call PRA3_fw_waitAndExec;
    }];

    _entry
};

// ======================================================================
// 3. Entity created listener: auto-track spawned vehicles
// ======================================================================
["entityCreated", {
    params ["_entity"];

    if (!(_entity isKindOf "AllVehicles")) exitWith {};
    if (_entity isKindOf "Man") exitWith {};

    private _respawnTime = _entity getVariable ["respawnTime", -1];
    if (_respawnTime < 0) exitWith {};

    private _counter = _entity getVariable ["respawnCounter", 1];

    if (_counter == 0) then {
        // Counter 0 means schedule an immediate respawn cycle
        diag_log format [
            "[PRA3 VehicleRespawn] Entity '%1' has respawnCounter=0, scheduling immediate respawn.",
            typeOf _entity
        ];

        [{
            _this call FUNC(doRespawn);
        }, 0.5, [
            _entity,
            typeOf _entity,
            vehicleVarName _entity,
            getPosATL _entity,
            getDir _entity,
            _entity getVariable ["respawnCondition", "true"],
            0
        ]] call PRA3_fw_waitAndExec;
    } else {
        // Normal registration
        private _entry = [_entity] call FUNC(registerVehicle);

        if (count _entry > 0) then {
            private _vehSide = _entry get "side";
            private _vehName = getText (configFile >> "CfgVehicles" >> typeOf _entity >> "displayName");

            // Notify owning side that the vehicle is available
            if !(_vehSide isEqualTo sideUnknown) then {
                ["vehicleAvailable", [_vehName]] call PRA3_fw_fireTarget;
            };
        };
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// 4. Abandoned vehicle state machine
// ======================================================================
private _abSM = ["VehicleAbandonSM", 2] call PRA3_fw_createSM;

// Working copy of tracked vehicles for iteration
GVAR(abandonCheckList)  = [];
GVAR(abandonCheckIndex) = 0;

// ------------------------------------------------------------------
// State: init — snapshot the current tracked list
// ------------------------------------------------------------------
[_abSM, "init", {
    GVAR(abandonCheckList)  = +GVAR(trackedVehicles);
    GVAR(abandonCheckIndex) = 0;
}, {
    if (count GVAR(abandonCheckList) > 0) then {
        "check"
    } else {
        // Nothing to check; stay idle briefly then re-init
        ""
    };
}, {}] call PRA3_fw_addState;

// ------------------------------------------------------------------
// State: check — process one vehicle per tick
// ------------------------------------------------------------------
[_abSM, "check", {}, {
    if (GVAR(abandonCheckIndex) >= count GVAR(abandonCheckList)) exitWith {
        // All processed — loop back
        "init"
    };

    private _entry = GVAR(abandonCheckList) select GVAR(abandonCheckIndex);
    GVAR(abandonCheckIndex) = GVAR(abandonCheckIndex) + 1;

    private _veh = _entry get "vehicle";

    // Skip null/destroyed vehicles
    if (isNull _veh || {!alive _veh}) exitWith { "" };

    private _spawnPos = _entry get "spawnPosition";
    private _vehPos   = getPosATL _veh;
    private _distFromSpawn = _spawnPos distance2D _vehPos;

    // --- Check 1: near spawn position? ---
    if (_distFromSpawn < GVAR(abandonedVehicleRadius)) exitWith {
        _entry set ["abandonTimer", -1];
        ""
    };

    // --- Check 2: has crew? ---
    if (count crew _veh > 0) exitWith {
        _entry set ["abandonTimer", -1];
        ""
    };

    // --- Check 3: players nearby? ---
    private _playersNear = _vehPos nearEntities ["CAManBase", GVAR(abandonedVehicleRadius)];
    private _hasPlayerNear = { isPlayer _x } count _playersNear > 0;

    if (_hasPlayerNear) exitWith {
        _entry set ["abandonTimer", -1];
        ""
    };

    // --- None of the above: start or continue abandon timer ---
    private _timer = _entry getOrDefault ["abandonTimer", -1];
    if (_timer < 0) then {
        // Start the timer
        _entry set ["abandonTimer", diag_tickTime];
    } else {
        // Check if enough time has passed
        private _elapsed = diag_tickTime - _timer;
        if (_elapsed >= GVAR(abandonedVehicleTime)) then {
            diag_log format [
                "[PRA3 VehicleRespawn] Vehicle '%1' (%2) abandoned for %3s — scheduling respawn.",
                _entry get "varName", _entry get "type", round _elapsed
            ];

            // Remove from tracked list
            private _liveIdx = GVAR(trackedVehicles) findIf {
                (_x get "vehicle") isEqualTo _veh
            };
            if (_liveIdx >= 0) then {
                GVAR(trackedVehicles) deleteAt _liveIdx;
            };

            // Schedule respawn
            [{
                _this call FUNC(doRespawn);
            }, 0.5, [
                _veh,
                _entry get "type",
                _entry get "varName",
                _entry get "spawnPosition",
                _entry get "spawnDirection",
                _entry get "respawnCondition",
                _entry get "respawnCounter"
            ]] call PRA3_fw_waitAndExec;
        };
    };

    ""  // stay in check state
}, {}] call PRA3_fw_addState;

// Start the abandoned vehicle SM
[_abSM, "init"] call PRA3_fw_startSM;

diag_log "[PRA3 VehicleRespawn] Server vehicle respawn system active.";
