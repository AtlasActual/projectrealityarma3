#include "macros.hpp"
/*
    Project Reality ArmA 3 - Core\fn_compile.sqf

    Author: joko // Jonas

    Description:
    Compile and Compress a function

    Parameter(s):
    0: Path to Function <STRING>
    1: Function Name <STRING>

    Returns:
    None
*/
params [["_functionPath", "", [""]], ["_functionVarName", "", [""]]];

#ifdef PRA3_DEBUGFULL
    private _debug = "private _fnc_scriptMap = if (isNil '_fnc_scriptMap') then {[_fnc_scriptName]} else {_fnc_scriptMap + [_fnc_scriptName]};";
#else
    private _debug = "";
#endif

private _header = format ["private _fnc_scriptNameParent = if (isNil '_fnc_scriptName') then {'%1'} else {_fnc_scriptName}; private _fnc_scriptName = '%1'; scriptName _fnc_scriptName; scopeName 'Main'; %2", _functionVarName, _debug];

private _funcString = _header + preprocessFileLineNumbers _functionPath;

private _fncCode = compile _funcString;

{
    _x setVariable [_functionVarName, _fncCode];
    nil
} count [missionNamespace, uiNamespace, parsingNamespace];

GVAR(functionCache) pushBack _functionVarName;
nil
