#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas

    Description:
    init for ListBox Data

    Parameter(s):
    None

    Returns:
    None
*/
GVAR(lnbDataControlCache) = [];
GVAR(lnbDataDataCache) = false call CFUNC(createNamespace);

[{
    GVAR(lnbDataControlCache) = GVAR(lnbDataControlCache) - [controlNull];
}, 1] call CFUNC(addPerFrameHandler);