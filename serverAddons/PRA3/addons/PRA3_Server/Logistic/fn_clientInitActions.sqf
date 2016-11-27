#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas, BadGuy

    Description:
    Logistic system

    Parameter(s):
    None

    Returns:
    None
*/

[
    {format [MLOC(Drag), getText(configFile >> "CfgVehicles" >> typeOf cursorObject >> "displayName")]},
    GVAR(DragableClasses),
    3,
    {
        (isNull assignedGunner _target) &&
        isNull (CLib_Player getVariable [QGVAR(Item), objNull]) &&
        isNull (_target getVariable [QGVAR(Player), objNull]) &&
        (_target getVariable ["isDragable", 0] == 1)
    },
    {
        params ["_draggedObject"];
        [FUNC(dragObject), [_draggedObject, CLib_Player], "logistic"] call CFUNC(mutex);
    }
] call CFUNC(addAction);

[
    QLSTRING(Drop),
    CLib_Player,
    0,
    {!(isNull (CLib_Player getVariable [QGVAR(Item), objNull]))},
    {
        [CLib_Player] call FUNC(dropObject);
    }, ["ignoredCanInteractConditions",["isNotDragging"]]
] call CFUNC(addAction);

[
    {format[MLOC(loadItem), getText(configFile >> "CfgVehicles" >> typeof cursorObject >> "displayName")]},
    GVAR(CargoClasses),
    10,
    {!(isNull (CLib_Player getVariable [QGVAR(Item), objNull])) && !((CLib_Player getVariable [QGVAR(Item), objNull]) isEqualTo _target) },
    {
        params ["_vehicle"];
        [{
            params ["_vehicle"];
            private _draggedObject = CLib_Player getVariable [QGVAR(Item), objNull];

            private _cargoSize = _draggedObject getVariable ["cargoSize", 0];
            private _ItemArray = _vehicle getVariable [QGVAR(CargoItems), []];
            private _cargoCapacity = _vehicle getVariable ["cargoCapacity", 0];
            {
                _cargoCapacity = _cargoCapacity - (_x getVariable ["cargoSize", 0]);
            } count _ItemArray;

            if (_cargoCapacity < _cargoSize) exitWith {
                [MLOC(noCargoSpace)] call EFUNC(Common,displayNotification);
            };


            detach _draggedObject;
            CLib_Player playAction "released";

            ["blockDamage", _draggedObject, [_draggedObject, true]] call CFUNC(targetEvent);
            ["hideObject", [_draggedObject, true]] call CFUNC(serverEvent);
            ["enableSimulation", [_draggedObject, false]] call CFUNC(serverEvent);

            _draggedObject setPos [0,0,0];

            _ItemArray pushBack _draggedObject;
            _vehicle setVariable [QGVAR(CargoItems), _ItemArray, true];

            CLib_Player setVariable [QGVAR(Item), objNull, true];
            _draggedObject setVariable [QGVAR(Player), objNull, true];

            ["forceWalk","Logistic",false] call CFUNC(setStatusEffect);

            CLib_Player action ["SwitchWeapon", CLib_Player, CLib_Player, 0];
        }, _vehicle, "logistic"] call CFUNC(mutex);
    }, ["ignoredCanInteractConditions",["isNotDragging"]]
] call CFUNC(addAction);

[
    {format[MLOC(UnloadItem), getText(configFile >> "CfgVehicles" >> typeof cursorTarget >> "displayName")]},
    GVAR(CargoClasses),
    10,
    {
        isNull (CLib_Player getVariable [QGVAR(Item), objNull]) && !((_target getVariable [QGVAR(CargoItems), []]) isEqualTo []) && CLib_Player == vehicle CLib_Player
    },
    {
        params ["_vehicle"];
        [{
            params ["_vehicle"];
            private _draggedObjectArray = _vehicle getVariable [QGVAR(CargoItems),[ObjNull]];
            private _draggedObject = _draggedObjectArray deleteAt 0;
            ["blockDamage", _draggedObject, [_draggedObject, false]] call CFUNC(targetEvent);
            ["hideObject", [_draggedObject, false]] call CFUNC(serverEvent);
            ["enableSimulation", [_draggedObject, true]] call CFUNC(serverEvent);
            [_draggedObject, CLib_Player] call FUNC(dragObject);
            _vehicle setVariable [QGVAR(CargoItems), _draggedObjectArray, true];
        }, _vehicle, "logistic"] call CFUNC(mutex);
    }
] call CFUNC(addAction);
