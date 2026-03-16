#include "script_component.hpp"
/*
    FUNC(get)

    Description:
        Looks up a sector logic unit by its name from the master
        storage object.

    Params:
        _sectorName - (String) name of the sector (same as the marker name)

    Returns:
        Object - the sector logic, or objNull if not found
*/

params ["_sectorName"];

GVAR(masterLogic) getVariable [_sectorName, objNull]
