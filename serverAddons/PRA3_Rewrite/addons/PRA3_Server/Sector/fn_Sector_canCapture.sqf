#include "script_component.hpp"
/*
    FUNC(canCapture)

    Description:
        Checks whether a sector is eligible for capture under the
        Advance-and-Secure dependency rules. A sector can be captured
        when at least one of its dependency sectors is held by a side
        different from the sector's current owner. Sectors with no
        dependencies are always capturable.

    Params:
        _sector - (Object) the sector logic unit

    Returns:
        Boolean - true if the sector may be attacked / captured
*/

params ["_sector"];

if (isNull _sector) exitWith { false };

private _ownerSide = _sector getVariable [QGVAR(ownerSide), sideUnknown];
private _deps = _sector getVariable [QGVAR(dependencies), []];

// Sectors without dependencies are always contestable
if (_deps isEqualTo []) exitWith { true };

private _capturable = false;

{
    private _depSector = [_x] call FUNC(get);
    if (!isNull _depSector) then {
        private _depOwner = _depSector getVariable [QGVAR(ownerSide), sideUnknown];
        // A dependency held by a different side (and not neutral) enables capture
        if (!(_depOwner isEqualTo sideUnknown) && {!(_depOwner isEqualTo _ownerSide)}) exitWith {
            _capturable = true;
        };
    };
} forEach _deps;

_capturable
