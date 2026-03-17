#include "script_component.hpp"
/*
    FUNC(create)

    Description:
        Creates a new squad for the calling player. Mutex-protected
        under the "respawn" lock. Validates the requested squad type,
        leaves the current squad, creates a fresh group, assigns a
        unique phonetic name, and applies group metadata.

    Parameters:
        _description - Display name / description for the squad
        _type        - Squad type identifier (e.g. "infantry", "armor")
*/

params ["_description", "_type"];

// Wrap the entire operation in the respawn mutex
["respawn", {
    params ["_description", "_type"];

    // Strip leading whitespace from description
    private _trimmed = _description;
    while {count _trimmed > 0 && {(_trimmed select [0, 1]) isEqualTo " "}} do {
        _trimmed = _trimmed select [1];
    };
    _description = _trimmed;

    // Validate that this squad type is permitted
    private _allowed = [_type] call FUNC(typeAllowed);
    if (!_allowed) exitWith {
        diag_log format [
            "[PRA3 Squad] Create rejected: type '%1' not allowed for %2",
            _type, name player
        ];
        systemChat "Cannot create a squad of that type.";
    };

    // Leave current squad first
    [] call FUNC(leave);

    // Create a new group on the player's side
    private _newGroup = createGroup [playerSide, true];

    // Obtain the next available squad identifier
    private _squadId = [] call FUNC(nextId);

    // Configure the group identity
    _newGroup setGroupIdGlobal [_squadId];

    // Store metadata as group variables
    _newGroup setVariable [QGVAR(description), _description, true];
    _newGroup setVariable [QGVAR(type), _type, true];

    // Move the player into the newly created group
    [player] joinSilent _newGroup;

    // Register this squad ID in the tracked list
    if (isNil QGVAR(squadIds)) then { GVAR(squadIds) = []; };
    GVAR(squadIds) pushBackUnique _squadId;

    // Notify local systems of the group change
    ["groupChanged", [player, _newGroup]] call PRA3_fw_fireEvent;

    diag_log format [
        "[PRA3 Squad] Created squad '%1' (%2) type=%3 by %4",
        _squadId, _description, _type, name player
    ];

}, [_description, _type]] call PRA3_fw_mutexLock;
