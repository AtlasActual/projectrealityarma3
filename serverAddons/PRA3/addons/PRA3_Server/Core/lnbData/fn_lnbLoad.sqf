#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas, NetFusion

    Description:
    Save Data from lnb Data

    Parameter(s):
    0: Controll or IDC from Dialog <Number, Controll>
    1: Row and Colum <Array<Number>>

    Returns:
    Variable from lnbData <Any>
*/
params ["_control", "_rowAndColumn"];

private _index = _control lnbValue _rowAndColumn;
GVAR(lnbDataDataCache) getVariable (str _index);