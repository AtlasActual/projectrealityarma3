#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Description:
        Server-side Logistic module initialisation. Monitors newly
        created entities for cargo capacity and marks them accordingly.
        Registers the "spawnCrate" event handler that delegates to
        FUNC(createCrate) for server-authoritative crate spawning.

    Called once on the server during module init.
*/

if (!isServer) exitWith {};

// ======================================================================
// 1. Storage for vehicle cargo inventories
// ======================================================================
// vehicleNetId -> array of loaded object netIds
GVAR(vehicleCargo) = createHashMap;

// Maximum cargo slots per vehicle (read from config or default)
GVAR(defaultCargoCapacity) = 4;

// ======================================================================
// 2. Listen to "entityCreated" — tag entities with cargo capacity
// ======================================================================
["entityCreated", {
    params ["_entity"];

    if (isNull _entity) exitWith {};

    // Check if the entity class has a cargo capacity defined in mission config
    private _entityType = typeOf _entity;
    private _cfgSides   = missionConfigFile >> "PRA3" >> "Factions";

    private _hasCargo = false;
    private _capacity = 0;

    if (!isNull _cfgSides) then {
        for "_i" from 0 to (count _cfgSides - 1) do {
            private _sideCfg = _cfgSides select _i;
            if (!isClass _sideCfg) then { continue };

            private _logCfg = _sideCfg >> "SupplySetup" >> "CargoVehicles" >> _entityType;
            if (!isNull _logCfg) exitWith {
                _hasCargo = true;
                _capacity = getNumber (_logCfg >> "capacity");
                if (_capacity <= 0) then {
                    _capacity = GVAR(defaultCargoCapacity);
                };
            };
        };
    };

    // Fallback: check if entity type is in any side's cargoClasses array
    if (!_hasCargo) then {
        if (!isNull _cfgSides) then {
            for "_i" from 0 to (count _cfgSides - 1) do {
                private _sideCfg = _cfgSides select _i;
                if (!isClass _sideCfg) then { continue };

                private _cargoArr = getArray (_sideCfg >> "SupplySetup" >> "cargoClasses");
                {
                    if (_entity isKindOf _x) exitWith {
                        _hasCargo = true;
                        _capacity = GVAR(defaultCargoCapacity);
                    };
                } forEach _cargoArr;

                if (_hasCargo) exitWith {};
            };
        };
    };

    if (_hasCargo) then {
        _entity setVariable [QGVAR(hasInventory), true, true];
        _entity setVariable [QGVAR(cargoCapacity), _capacity, true];
        _entity setVariable [QGVAR(cargoLoaded), [], true];

        GVAR(vehicleCargo) set [netId _entity, []];

        diag_log format [
            "[PRA3 Logistic] Entity '%1' (%2) tagged with cargo capacity %3",
            _entity, _entityType, _capacity
        ];
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// 3. Register "spawnCrate" event — delegates to createCrate function
// ======================================================================
["spawnCrate", {
    params ["_crateClass", "_position", "_side"];

    [_crateClass, _position, _side] call FUNC(createCrate);

    diag_log format [
        "[PRA3 Logistic] Crate spawn request processed — class: %1, side: %2",
        _crateClass, _side
    ];
}] call PRA3_fw_addHandler;

// ======================================================================
// 4. Clean up cargo references when vehicles are destroyed
// ======================================================================
["entityKilled", {
    params ["_entity"];

    private _netId = netId _entity;
    if (_netId in GVAR(vehicleCargo)) then {
        // Unload all cargo items onto the ground before removal
        private _cargoList = _entity getVariable [QGVAR(cargoLoaded), []];
        private _dropPos = getPosATL _entity;

        {
            private _cargoObj = objectFromNetId _x;
            if (!isNull _cargoObj) then {
                _cargoObj hideObjectGlobal false;
                _cargoObj enableSimulationGlobal true;

                private _safePos = [_dropPos, 15] call PRA3_fw_safePos;
                _cargoObj setPosATL [_safePos select 0, _safePos select 1, 0];
            };
        } forEach _cargoList;

        GVAR(vehicleCargo) deleteAt _netId;
        _entity setVariable [QGVAR(cargoLoaded), [], true];

        diag_log format ["[PRA3 Logistic] Vehicle destroyed — dumped %1 cargo items", count _cargoList];
    };
}] call PRA3_fw_addHandler;

diag_log "[PRA3 Logistic] Server setup complete.";
