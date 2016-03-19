#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas, NetFusion

    Description:
    Init for Rally System for Leaders

    Parameter(s):
    None

    Returns:
    None
*/
[QGVAR(Rally), missionConfigFile >> "PRA3" >> "CfgSquadRallyPoint"] call CFUNC(loadSettings);

["BASE", "a3\ui_f\data\map\Markers\Military\box_ca.paa", -1, getMarkerPos "base_west", {playerSide == west}] call FUNC(addDeploymentPoint);
["BASE", "a3\ui_f\data\map\Markers\Military\box_ca.paa", -1, getMarkerPos "base_east", {playerSide == east}] call FUNC(addDeploymentPoint);

[{
    {
        private _pointDetails = GVAR(deploymentLogic) getVariable [_x, []];
        _pointDetails params ["_name", "_icon", "_tickets", "_position", "_condition", "_args", "_objects"];

        if (_args isEqualType grpNull) then {
            if (isNull _args) then {
                {
                    deleteVehicle _x;
                    nil
                } count _objects;
                GVAR(deploymentLogic) setVariable [_x, nil, true];
            } else {
                private _maxEnemyCount = [QGVAR(Rally_maxEnemyCount), 1] call CFUNC(getSetting);
                private _maxEnemyCountRadius = [QGVAR(Rally_maxEnemyCountRadius), 10] call CFUNC(getSetting);

                private _rallySide = side _args;
                private _enemyCount = {(side group _x) != _rallySide} count (nearestObjects [_position, ["CAManBase"], _maxEnemyCountRadius]);

                if (_enemyCount >= _maxEnemyCount) then {
                    [_args] call FUNC(destroyRally);
                    GVAR(deploymentLogic) setVariable [_x, nil, true];
                    [UIVAR(RespawnScreen_DeploymentManagement_update), _args] call CFUNC(targetEvent);
                };
            };
        };
        nil
    } count (allVariables GVAR(deploymentLogic));
}, 0.2] call CFUNC(addPerFrameHandler);