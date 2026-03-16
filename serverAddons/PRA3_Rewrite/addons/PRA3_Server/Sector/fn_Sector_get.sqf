#include "script_component.hpp"
/*
    FUNC(get)

    Description:
        Looks up a sector logic object by its name from the master
        storage object. Returns objNull if not found.

    Params:
        _sectorName - (String) name of the sector to retrieve

    Returns:
        Object - the sector logic, or objNull
*/

params ["_sectorName"];

GVAR(masterObj) getVariable [_sectorName, objNull]
