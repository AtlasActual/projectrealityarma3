#include "script_component.hpp"
/*
    FUNC(calcWeight)

    Description:
        Calculates the total weight of an object or container by summing
        the mass values of all magazines, weapons, items, and backpacks
        contained within it. A 0.5 multiplier is applied for game balance.

    Params:
        0: _object - OBJECT - the object/container to weigh

    Returns: NUMBER - total calculated weight (after balance multiplier)
*/

params ["_object"];

if (isNull _object) exitWith { 0 };

private _totalMass = 0;

// ======================================================================
// 1. Sum magazine masses
// ======================================================================
private _magazines = magazineCargo _object;

if (!isNil "_magazines" && {!(_magazines isEqualTo [])}) then {
    // Build a frequency map to avoid duplicate config lookups
    private _magCounts = createHashMap;
    {
        private _cur = _magCounts getOrDefault [_x, 0];
        _magCounts set [_x, _cur + 1];
    } forEach _magazines;

    {
        private _className = _x;
        private _count     = _y;
        private _mass = getNumber (configFile >> "CfgMagazines" >> _className >> "mass");
        _totalMass = _totalMass + (_mass * _count);
    } forEach _magCounts;
};

// ======================================================================
// 2. Sum weapon masses
// ======================================================================
private _weapons = weaponCargo _object;

if (!isNil "_weapons" && {!(_weapons isEqualTo [])}) then {
    private _wpnCounts = createHashMap;
    {
        private _cur = _wpnCounts getOrDefault [_x, 0];
        _wpnCounts set [_x, _cur + 1];
    } forEach _weapons;

    {
        private _className = _x;
        private _count     = _y;
        private _mass = getNumber (configFile >> "CfgWeapons" >> _className >> "mass");
        _totalMass = _totalMass + (_mass * _count);
    } forEach _wpnCounts;
};

// ======================================================================
// 3. Sum item masses
// ======================================================================
private _items = itemCargo _object;

if (!isNil "_items" && {!(_items isEqualTo [])}) then {
    private _itemCounts = createHashMap;
    {
        private _cur = _itemCounts getOrDefault [_x, 0];
        _itemCounts set [_x, _cur + 1];
    } forEach _items;

    {
        private _className = _x;
        private _count     = _y;
        // Items can be in CfgWeapons or CfgGlasses — check both
        private _mass = getNumber (configFile >> "CfgWeapons" >> _className >> "mass");
        if (_mass == 0) then {
            _mass = getNumber (configFile >> "CfgGlasses" >> _className >> "mass");
        };
        _totalMass = _totalMass + (_mass * _count);
    } forEach _itemCounts;
};

// ======================================================================
// 4. Sum backpack masses (including their contents recursively)
// ======================================================================
private _backpacks = backpackCargo _object;

if (!isNil "_backpacks" && {!(_backpacks isEqualTo [])}) then {
    {
        // Base mass of the backpack itself
        private _bpClass = typeOf _x;
        private _bpBaseMass = getNumber (configFile >> "CfgVehicles" >> _bpClass >> "mass");
        _totalMass = _totalMass + _bpBaseMass;

        // Recursively calculate contents of the backpack
        private _contentsMass = [_x] call FUNC(calcWeight);
        // The recursive call already applies the multiplier, so we
        // need to reverse it here to avoid double-application
        _totalMass = _totalMass + (_contentsMass / 0.5);
    } forEach _backpacks;
};

// ======================================================================
// 5. Add the base mass of the object itself (e.g. crate body)
// ======================================================================
private _baseMass = getNumber (configFile >> "CfgVehicles" >> typeOf _object >> "mass");
_totalMass = _totalMass + _baseMass;

// ======================================================================
// 6. Apply balance multiplier
// ======================================================================
private _balanceMultiplier = 0.5;
private _finalWeight = _totalMass * _balanceMultiplier;

_finalWeight
