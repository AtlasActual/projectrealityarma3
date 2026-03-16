#include "script_component.hpp"
/*
    FUNC(leave)

    Description:
        Removes the calling player from their current squad.
        Mutex-protected under the "respawn" lock. Creates a fresh
        empty group for the player so they are not left in an
        invalid state.

    Parameters: none
*/

["respawn", {
    private _oldGroup = group player;

    // Create a new empty group for the departing player
    private _soloGroup = createGroup [playerSide, true];

    // Move the player out of the old group into the fresh one
    [player] joinSilent _soloGroup;

    // Notify local systems of the change
    ["groupChanged", [player, _soloGroup]] call PRA3_fw_fireEvent;

    diag_log format [
        "[PRA3 Squad] %1 left squad '%2'",
        name player, groupId _oldGroup
    ];

}, []] call PRA3_fw_mutexLock;
