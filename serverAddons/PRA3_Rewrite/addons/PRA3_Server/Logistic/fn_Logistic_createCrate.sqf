#include "script_component.hpp"
/*
    FUNC(createCrate)

    Description:
        Server-side crate spawner. Creates a supply crate at a safe
        position near the requested location, clears all default cargo,
        then populates it from the mission config definition. Each item
        type is detected and added via the correct cargo command.

    Params:
        0: _crateClassName - STRING - config class name for the crate
        1: _position       - ARRAY  - desired spawn position [x, y, z]
        2: _side           - SIDE   - owning side (west, east, resistance)

    Returns: OBJECT - the created crate (or objNull on failure)
*/

if (!isServer) exitWith { objNull };

params ["_crateClassName", "_position", "_side"];

// ======================================================================
// 1. Resolve the crate config from mission config
// ======================================================================
private _sideStr = switch (_side) do {
    case west:       { "west" };
    case east:       { "east" };
    case resistance: { "resistance" };
    default          { "" };
};

if (_sideStr == "") exitWith {
    diag_log format ["[PRA3 Logistic] createCrate — invalid side: %1", _side];
    objNull
};

private _crateCfg = missionConfigFile >> "PRA3" >> "Factions" >> _sideStr >> "SupplySetup" >> "Crates" >> _crateClassName;

if (isNull _crateCfg) exitWith {
    diag_log format [
        "[PRA3 Logistic] createCrate — config not found: %1 for side %2",
        _crateClassName, _sideStr
    ];
    objNull
};

// ======================================================================
// 2. Determine the vehicle classname to spawn
// ======================================================================
private _vehicleClass = getText (_crateCfg >> "vehicleClass");
if (_vehicleClass == "") then {
    // Default crate model if none specified
    _vehicleClass = "B_supplyCrate_F";
};

// ======================================================================
// 3. Find a safe spawn position
// ======================================================================
private _safePos = [_position, 20] call PRA3_fw_safePos;
private _spawnPos = [_safePos select 0, _safePos select 1, 0];

// ======================================================================
// 4. Create the crate object
// ======================================================================
private _crate = createVehicle [_vehicleClass, _spawnPos, [], 0, "CAN_COLLIDE"];
_crate setPosATL _spawnPos;

// ======================================================================
// 5. Clear all default cargo
// ======================================================================
clearWeaponCargoGlobal   _crate;
clearMagazineCargoGlobal _crate;
clearItemCargoGlobal     _crate;
clearBackpackCargoGlobal _crate;

// ======================================================================
// 6. Read contents from config and add to crate
// ======================================================================
private _contentsCfg = _crateCfg >> "Contents";

if (!isNull _contentsCfg) then {
    for "_i" from 0 to (count _contentsCfg - 1) do {
        private _entryCfg = _contentsCfg select _i;
        if (!isClass _entryCfg) then { continue };

        private _itemClass = getText (_entryCfg >> "className");
        private _itemCount = getNumber (_entryCfg >> "count");

        if (_itemClass == "" || {_itemCount <= 0}) then { continue };

        // Detect item type by checking which config category it belongs to
        private _added = false;

        // Check CfgWeapons first (weapons, accessories, uniforms, vests)
        if (!_added && {isClass (configFile >> "CfgWeapons" >> _itemClass)}) then {
            // Distinguish between actual weapons and equipment items
            private _cfgType = getNumber (configFile >> "CfgWeapons" >> _itemClass >> "type");
            // type 1 = primary, 2 = handgun, 4 = secondary (launcher)
            // type 131072 = binocular, 4096 = compass/watch/etc
            if (_cfgType in [1, 2, 4, 131072]) then {
                _crate addWeaponCargoGlobal [_itemClass, _itemCount];
            } else {
                _crate addItemCargoGlobal [_itemClass, _itemCount];
            };
            _added = true;
        };

        // Check CfgMagazines
        if (!_added && {isClass (configFile >> "CfgMagazines" >> _itemClass)}) then {
            _crate addMagazineCargoGlobal [_itemClass, _itemCount];
            _added = true;
        };

        // Check CfgVehicles for backpacks
        if (!_added && {isClass (configFile >> "CfgVehicles" >> _itemClass)}) then {
            private _isBackpack = getNumber (configFile >> "CfgVehicles" >> _itemClass >> "isBackpack");
            if (_isBackpack == 1) then {
                _crate addBackpackCargoGlobal [_itemClass, _itemCount];
            } else {
                _crate addItemCargoGlobal [_itemClass, _itemCount];
            };
            _added = true;
        };

        // Check CfgGlasses (goggles/facewear)
        if (!_added && {isClass (configFile >> "CfgGlasses" >> _itemClass)}) then {
            _crate addItemCargoGlobal [_itemClass, _itemCount];
            _added = true;
        };

        // Fallback: treat as generic item
        if (!_added) then {
            _crate addItemCargoGlobal [_itemClass, _itemCount];
            diag_log format [
                "[PRA3 Logistic] createCrate — unknown item type '%1', added as item",
                _itemClass
            ];
        };
    };
};

// ======================================================================
// 7. Tag the crate with logistic metadata
// ======================================================================
_crate setVariable [QGVAR(hasInventory), true, true];
_crate setVariable [QGVAR(crateType), _crateClassName, true];
_crate setVariable [QGVAR(crateSide), _side, true];

// ======================================================================
// 8. Broadcast creation event
// ======================================================================
["logisticCrateSpawned", [_crate, _crateClassName, _side]] call PRA3_fw_fireGlobal;

diag_log format [
    "[PRA3 Logistic] Crate created — class: %1, vehicle: %2, pos: %3, side: %4, items: %5",
    _crateClassName, _vehicleClass, _spawnPos, _sideStr,
    if (!isNull _contentsCfg) then { count _contentsCfg } else { 0 }
];

_crate
