#include "script_component.hpp"
/*
    FUNC(kick)

    Description:
        Kicks a target unit from the caller's squad. Only the group
        leader is permitted to kick members. Mutex-protected under
        the "respawn" lock. The kicked player is moved into a new
        empty group.

    Parameters:
        _targetUnit - The unit (player object) to remove from the squad
*/

params ["_targetUnit"];

["respawn", {
    params ["_targetUnit"];

    // Verify that the caller is the group leader
    private _callerGroup = group player;
    if !(player isEqualTo (leader _callerGroup)) exitWith {
        systemChat "Only the squad leader can kick members.";
        diag_log format [
            "[PRA3 Squad] Kick rejected: %1 is not leader of %2",
            name player, groupId _callerGroup
        ];
    };

    // Verify the target is actually in the same group
    if !(group _targetUnit isEqualTo _callerGroup) exitWith {
        systemChat "That player is not in your squad.";
    };

    // Create a new empty group for the kicked player
    private _exileGroup = createGroup [side _targetUnit, true];
    [_targetUnit] joinSilent _exileGroup;

    // Notify the kicked player's machine about the group change
    ["groupChanged", [_targetUnit, _exileGroup], owner _targetUnit] call PRA3_fw_fireTarget;

    systemChat format ["%1 has been removed from the squad.", name _targetUnit];

    diag_log format [
        "[PRA3 Squad] %1 kicked %2 from squad '%3'",
        name player, name _targetUnit, groupId _callerGroup
    ];

}, [_targetUnit]] call PRA3_fw_mutexLock;
