#include "script_component.hpp"
/*
    FUNC(equip)

    Description:
        Fully applies a kit loadout to the given player unit. Strips all
        existing gear and replaces it with the kit configuration: uniform,
        vest, backpack, headgear, weapons with attachments, magazines,
        assigned items, general items, and role trait variables.

    Params:
        0: _unit      - OBJECT - the player unit to equip
        1: _kitConfig - CONFIG - config path to the kit entry

    Returns: nothing
*/

params ["_unit", "_kitConfig"];

if (!local _unit) exitWith {
    diag_log format ["[PRA3 Kit] WARNING: equip called on non-local unit %1", _unit];
};

// Resolve string classname to config path
if (_kitConfig isEqualType "") then {
    private _sideStr = switch (side group _unit) do {
        case west: { "West" };
        case east: { "East" };
        case independent: { "Indep" };
        default { "West" };
    };
    _kitConfig = missionConfigFile >> "PRA3" >> "Factions" >> _sideStr >> "Kits" >> _kitConfig;
    if (!isClass _kitConfig) exitWith {
        diag_log format ["[PRA3 Kit] equip: invalid kit classname '%1' for side %2", _this select 1, side group _unit];
    };
};

private _kitDetails = [_kitConfig] call FUNC(details);
private _kitClassName = configName _kitConfig;

// ======================================================================
// 1. Strip all existing gear
// ======================================================================
removeAllWeapons _unit;
removeAllItems _unit;
removeAllAssignedItems _unit;
removeUniform _unit;
removeVest _unit;
removeBackpack _unit;
removeHeadgear _unit;
removeGoggles _unit;

// ======================================================================
// 2. Apply containers (uniform, vest, backpack, headgear)
// ======================================================================
private _uniform = _kitDetails get "uniform";
if (_uniform isNotEqualTo "") then {
    _unit forceAddUniform _uniform;
};

private _vest = _kitDetails get "vest";
if (_vest isNotEqualTo "") then {
    _unit addVest _vest;
};

private _backpack = _kitDetails get "backpack";
if (_backpack isNotEqualTo "") then {
    _unit addBackpack _backpack;
};

private _headgear = _kitDetails get "headgear";
if (_headgear isNotEqualTo "") then {
    _unit addHeadgear _headgear;
};

// ======================================================================
// 3. Add magazines before weapons (so weapons auto-load)
// ======================================================================
private _magazines = _kitDetails get "magazines";
{
    if (_x isEqualType []) then {
        // Format: [className, count]
        _x params ["_magClass", "_magCount"];
        for "_i" from 1 to _magCount do {
            _unit addMagazine _magClass;
        };
    } else {
        _unit addMagazine _x;
    };
} forEach _magazines;

// ======================================================================
// 4. Add weapons with attachments
// ======================================================================
private _weapons = _kitDetails get "weapons";
{
    if (_x isEqualType []) then {
        // Format: [weaponClass, muzzle, pointer, optic] or subsets
        _x params [
            "_weaponClass",
            ["_muzzle", ""],
            ["_pointer", ""],
            ["_optic", ""]
        ];

        _unit addWeapon _weaponClass;

        if (_muzzle isNotEqualTo "") then {
            _unit addWeaponItem [_weaponClass, _muzzle];
        };
        if (_pointer isNotEqualTo "") then {
            _unit addWeaponItem [_weaponClass, _pointer];
        };
        if (_optic isNotEqualTo "") then {
            _unit addWeaponItem [_weaponClass, _optic];
        };
    } else {
        _unit addWeapon _x;
    };
} forEach _weapons;

// ======================================================================
// 5. Add assigned items (map, compass, watch, GPS, radio, NVGs)
// ======================================================================
private _assignedItems = _kitDetails get "assignedItems";
{
    _unit linkItem _x;
} forEach _assignedItems;

// ======================================================================
// 6. Add general items distributed across containers
// ======================================================================
private _items = _kitDetails get "items";
{
    if (_x isEqualType []) then {
        // Format: [itemClass, count] or [itemClass, count, container]
        _x params ["_itemClass", ["_itemCount", 1], ["_container", ""]];

        for "_i" from 1 to _itemCount do {
            switch (toLower _container) do {
                case "uniform": {
                    _unit addItemToUniform _itemClass;
                };
                case "vest": {
                    _unit addItemToVest _itemClass;
                };
                case "backpack": {
                    _unit addItemToBackpack _itemClass;
                };
                default {
                    _unit addItem _itemClass;
                };
            };
        };
    } else {
        _unit addItem _x;
    };
} forEach _items;

// ======================================================================
// 7. Set role trait variables
// ======================================================================
private _traits = _kitDetails get "traits";

private _isLeader   = (_traits getOrDefault ["isLeader",   0]) > 0;
private _isMedic    = (_traits getOrDefault ["isMedic",    0]) > 0;
private _isEngineer = (_traits getOrDefault ["isEngineer", 0]) > 0;
private _isPilot    = (_traits getOrDefault ["isPilot",    0]) > 0;
private _isCrew     = (_traits getOrDefault ["isCrew",     0]) > 0;

_unit setVariable [QGVAR(isLeader),   _isLeader,   true];
_unit setVariable [QGVAR(isMedic),    _isMedic,    true];
_unit setVariable [QGVAR(isEngineer), _isEngineer, true];
_unit setVariable [QGVAR(isPilot),    _isPilot,    true];
_unit setVariable [QGVAR(isCrew),     _isCrew,     true];

// Set engine-level unit traits for medic and engineer
_unit setUnitTrait ["Medic",    _isMedic];
_unit setUnitTrait ["Engineer", _isEngineer];

// ======================================================================
// 8. Store current kit reference
// ======================================================================
_unit setVariable [QGVAR(currentKit), _kitClassName, true];

diag_log format ["[PRA3 Kit] Equipped %1 with kit %2", name _unit, _kitClassName];
