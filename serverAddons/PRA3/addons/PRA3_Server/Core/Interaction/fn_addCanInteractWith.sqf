#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas

    Description:
    Add a Can Interact With Condition

    Parameter(s):
    0: Type <String>
    1: Conditions <Code>

    Returns:
    None
*/
if (isNil QGVAR(canInteractWithTypes)) exitWith {
    GVAR(canInteractWithTypes) = [_this];
};
GVAR(canInteractWithTypes) pushBackUnique _this;
nil
