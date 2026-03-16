#include "script_component.hpp"
/*
    FUNC(canCapture)

    Description:
        Determines whether a given side is allowed to capture a sector
        under the Advance and Secure dependency rules.

        A sector is capturable by a side when at least one of its
        dependency sectors is currently owned by that attacking side.
        Base sectors (empty dependency list or containing "base") are
        always contestable by any non-owning side.

    Params:
        _sector        - (Object) the sector logic to test
        _attackingSide - (Side)   the side attempting to capture

    Returns:
        Boolean - true if the sector can be captured by that side
*/

params ["_sector", "_attackingSide"];

if (isNull _sector) exitWith { false };

private _ownerSide    = _sector getVariable [QGVAR(ownerSide), sideUnknown];
private _dependencies = _sector getVariable [QGVAR(dependencies), []];

// Cannot "capture" a sector you already own
if (_ownerSide isEqualTo _attackingSide) exitWith { false };

// Base sectors or sectors with no dependencies: always contestable
if (_dependencies isEqualTo []) exitWith { true };

private _isBaseSector = false;
{
    if (toLower _x isEqualTo "base") exitWith {
        _isBaseSector = true;
    };
} forEach _dependencies;

if (_isBaseSector) exitWith { true };

// Standard AAS rule: at least one dependency must be owned by the attacker
private _canAttack = false;
{
    private _depSector = [_x] call FUNC(get);
    if (!isNull _depSector) then {
        private _depOwner = _depSector getVariable [QGVAR(ownerSide), sideUnknown];
        if (_depOwner isEqualTo _attackingSide) exitWith {
            _canAttack = true;
        };
    };
} forEach _dependencies;

_canAttack
