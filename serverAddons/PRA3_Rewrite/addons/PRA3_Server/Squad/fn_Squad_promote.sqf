#include "script_component.hpp"
/*
    FUNC(promote)

    Description:
        Promotes a target unit to squad leader. Only the current
        group leader may promote another member. Mutex-protected
        under the "respawn" lock.

    Parameters:
        _targetUnit - The unit (player object) to promote to leader
*/

params ["_targetUnit"];

["respawn", {
    params ["_targetUnit"];

    private _grp = group player;

    // Verify that the caller is the current leader
    if !(player isEqualTo (leader _grp)) exitWith {
        systemChat "Only the squad leader can promote members.";
        diag_log format [
            "[PRA3 Squad] Promote rejected: %1 is not leader of %2",
            name player, groupId _grp
        ];
    };

    // Verify the target belongs to the same group
    if !(group _targetUnit isEqualTo _grp) exitWith {
        systemChat "That player is not in your squad.";
    };

    // Promote the target to group leader
    [_grp, _targetUnit] remoteExec ["selectLeader", groupOwner _grp];

    // Notify all group members about the leadership change
    {
        if (isPlayer _x) then {
            ["groupChanged", [_x, _grp], owner _x] call PRA3_fw_fireTarget;
        };
    } forEach (units _grp);

    systemChat format ["%1 has been promoted to squad leader.", name _targetUnit];

    diag_log format [
        "[PRA3 Squad] %1 promoted %2 to leader of '%3'",
        name player, name _targetUnit, groupId _grp
    ];

}, [_targetUnit]] call PRA3_fw_mutexLock;
