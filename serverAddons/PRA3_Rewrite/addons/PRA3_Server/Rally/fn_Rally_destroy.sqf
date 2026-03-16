#include "script_component.hpp"
/*
    FUNC(destroy)

    Description:
        Removes a rally deployment point, clears the owning group's
        rally variable, removes the point from the live-tracking array,
        and optionally notifies squad members with a reason string.

    Parameters:
        0: _rallyPointId  — deployment point ID to remove  (String)
        1: _reason        — destruction reason tag          (String, optional)
                            "enemy" | "disbanded" | "manual" | ...

    Returns: nothing
*/

params [
    ["_rallyPointId", "", [""]],
    ["_reason", "manual", [""]]
];

if (_rallyPointId == "") exitWith {
    diag_log "[PRA3:Rally] destroy — no point ID provided.";
};

// ======================================================================
// 1. Identify the owning group before the point is purged
// ======================================================================
private _rec        = EGVAR(Deployment,pointStorage) getOrDefault [_rallyPointId, createHashMap];
private _ownerGroup = grpNull;

if (count _rec > 0) then {
    private _av = _rec getOrDefault ["availableFor", grpNull];
    if (_av isEqualType grpNull) then {
        _ownerGroup = _av;
    };
};

// ======================================================================
// 2. Remove the deployment point (linked objects deleted automatically)
// ======================================================================
[_rallyPointId] call EFUNC(Deployment,removePoint);

// ======================================================================
// 3. Clear the group's stored rally variable
// ======================================================================
if (!isNull _ownerGroup) then {
    _ownerGroup setVariable [QGVAR(rallyPointId), "", true];

    // Inform squad members
    ["rallyLost", [_reason], _ownerGroup] call PRA3_fw_fireTarget;
};

// ======================================================================
// 4. Remove from the server-side tracking array
// ======================================================================
private _pos = GVAR(liveRallies) find _rallyPointId;
if (_pos >= 0) then {
    GVAR(liveRallies) deleteAt _pos;
};

diag_log format ["[PRA3:Rally] Destroyed '%1' — reason: %2", _rallyPointId, _reason];
