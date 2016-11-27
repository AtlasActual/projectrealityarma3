#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: BadGuy, joko // Jonas

    Description:
    Initialize the

    Parameter(s):
    None

    Returns:
    None
*/

private _fncDrawAllSectors = {
    ["ATTACK"] call EFUNC(CompassUI,removeLineMarker);
    ["DEFEND"] call EFUNC(CompassUI,removeLineMarker);
    {
        [_x] call FUNC(drawSector);
        nil
    } count GVAR(allSectorsArray);
};

["sideChanged", _fncDrawAllSectors] call CFUNC(addEventhandler);

["sectorSideChanged", _fncDrawAllSectors] call CFUNC(addEventhandler);

[_fncDrawAllSectors, {
    !isNil QGVAR(ServerInitDone) && {GVAR(ServerInitDone)}
},[]] call CFUNC(waitUntil);
