#include "script_component.hpp"
/*
    FUNC(join)

    Description:
        Joins the calling player to an existing squad (group).
        Mutex-protected under the "respawn" lock. Validates that
        the target group has not reached its maximum capacity
        based on the group's type configuration.

    Parameters:
        _targetGroup - The group object to join
*/

params ["_targetGroup"];

["respawn", {
    params ["_targetGroup"];

    // Retrieve the group type to determine max capacity
    private _groupType = _targetGroup getVariable [QGVAR(type), "infantry"];
    private _typeCfg = missionConfigFile >> "PRA3" >> "TeamRoles" >> _groupType;

    private _maxMembers = getNumber (_typeCfg >> "maxMembers");
    if (_maxMembers isEqualTo 0) then {
        _maxMembers = 8;
    };

    // Check current group size against the cap
    private _currentSize = count (units _targetGroup);
    if (_currentSize >= _maxMembers) exitWith {
        systemChat format [
            "Squad is full (%1/%2).",
            _currentSize, _maxMembers
        ];
        diag_log format [
            "[PRA3 Squad] Join rejected: group %1 full (%2/%3) for %4",
            groupId _targetGroup, _currentSize, _maxMembers, name player
        ];
    };

    // Move player into the target group
    [player] joinSilent _targetGroup;

    // Notify local systems
    ["groupChanged", [player, _targetGroup]] call PRA3_fw_fireEvent;

    diag_log format [
        "[PRA3 Squad] %1 joined squad '%2' (%3/%4)",
        name player, groupId _targetGroup, count (units _targetGroup), _maxMembers
    ];

}, [_targetGroup]] call PRA3_fw_mutexLock;
