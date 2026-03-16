#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side map icon management using a state machine for
        incremental processing. Cycles through friendly units, groups,
        and vehicles in batches to spread load across frames. Manages
        icon lifecycle (creation, update, removal) via local map markers
        and draw event handlers.

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. State variables
// ======================================================================
GVAR(unitQueue)       = [];    // pending units to process
GVAR(groupQueue)      = [];    // pending groups to process
GVAR(vehicleQueue)    = [];    // pending vehicles to process
GVAR(batchSize)       = 8;     // items processed per tick
GVAR(refreshInterval) = 2;     // seconds between full collection passes
GVAR(lastCollectTime) = 0;

// Tracking hashmaps for active icons: key -> markerName
GVAR(unitIcons)    = createHashMap;
GVAR(groupIcons)   = createHashMap;
GVAR(vehicleIcons) = createHashMap;

// Set of keys seen this cycle (for removal of stale icons)
GVAR(seenUnits)    = createHashMap;
GVAR(seenGroups)   = createHashMap;
GVAR(seenVehicles) = createHashMap;

// ======================================================================
// 2. Build the state machine
// ======================================================================
private _sm = ["UnitTrackerSM", GVAR(refreshInterval)] call PRA3_fw_createSM;

// ------------------------------------------------------------------
// State: idle — collect all friendly entities, then move on
// ------------------------------------------------------------------
[_sm, "idle", {
    // Entry action: gather data
    if (isNull player) exitWith {};

    private _playerSide = side group player;

    // Reset seen-sets for this cycle
    GVAR(seenUnits)    = createHashMap;
    GVAR(seenGroups)   = createHashMap;
    GVAR(seenVehicles) = createHashMap;

    // Collect friendly units
    private _units = [];
    {
        if (!alive _x) then { continue };
        if (side group _x isNotEqualTo _playerSide) then { continue };
        if (_x getVariable [QEGVAR(Revive,unconscious), false]) then {
            // Still include — drawUnit handles the revive icon
        };
        _units pushBack _x;
    } forEach allUnits;
    GVAR(unitQueue) = _units;

    // Collect friendly groups (unique, with living leaders)
    private _groups = [];
    private _seenGrps = createHashMap;
    {
        private _grp = group _x;
        private _grpId = str _grp;
        if (_grpId in _seenGrps) then { continue };
        if (side _grp isNotEqualTo _playerSide) then { continue };
        if (isNull leader _grp) then { continue };
        if (!alive leader _grp) then { continue };
        _seenGrps set [_grpId, true];
        _groups pushBack _grp;
    } forEach allUnits;
    GVAR(groupQueue) = _groups;

    // Collect friendly vehicles with crew
    private _vehicles = [];
    private _seenVehs = createHashMap;
    {
        private _veh = vehicle _x;
        if (_veh isEqualTo _x) then { continue };  // on foot
        private _vehId = str _veh;
        if (_vehId in _seenVehs) then { continue };
        if (side group _x isNotEqualTo _playerSide) then { continue };
        _seenVehs set [_vehId, true];
        _vehicles pushBack _veh;
    } forEach allUnits;
    GVAR(vehicleQueue) = _vehicles;

    GVAR(lastCollectTime) = diag_tickTime;
}, {
    // Condition to transition: always move to processUnits immediately
    "processUnits"
}, {}] call PRA3_fw_addState;

// ------------------------------------------------------------------
// State: processUnits — batch-process unit icons
// ------------------------------------------------------------------
[_sm, "processUnits", {}, {
    // Per-tick processing
    private _batch = GVAR(batchSize) min count GVAR(unitQueue);

    for "_i" from 0 to (_batch - 1) do {
        if (count GVAR(unitQueue) == 0) then { break };
        private _unit = GVAR(unitQueue) deleteAt 0;

        if (isNull _unit || {!alive _unit}) then { continue };

        private _uid = str _unit;
        GVAR(seenUnits) set [_uid, true];
        [_unit] call FUNC(drawUnit);
    };

    // Transition when queue exhausted
    if (count GVAR(unitQueue) == 0) then {
        "processGroups"
    } else {
        ""  // stay in this state
    };
}, {}] call PRA3_fw_addState;

// ------------------------------------------------------------------
// State: processGroups — batch-process group icons
// ------------------------------------------------------------------
[_sm, "processGroups", {}, {
    private _batch = GVAR(batchSize) min count GVAR(groupQueue);

    for "_i" from 0 to (_batch - 1) do {
        if (count GVAR(groupQueue) == 0) then { break };
        private _grp = GVAR(groupQueue) deleteAt 0;

        if (isNull _grp) then { continue };
        if (!alive leader _grp) then { continue };

        private _gid = str _grp;
        GVAR(seenGroups) set [_gid, true];
        [_grp] call FUNC(drawGroup);
    };

    if (count GVAR(groupQueue) == 0) then {
        "processVehicles"
    } else {
        ""
    };
}, {}] call PRA3_fw_addState;

// ------------------------------------------------------------------
// State: processVehicles — batch-process vehicle icons
// ------------------------------------------------------------------
[_sm, "processVehicles", {}, {
    private _batch = GVAR(batchSize) min count GVAR(vehicleQueue);

    for "_i" from 0 to (_batch - 1) do {
        if (count GVAR(vehicleQueue) == 0) then { break };
        private _veh = GVAR(vehicleQueue) deleteAt 0;

        if (isNull _veh || {!alive _veh}) then { continue };

        private _vid = str _veh;
        GVAR(seenVehicles) set [_vid, true];
        [_veh] call FUNC(drawVehicle);
    };

    if (count GVAR(vehicleQueue) == 0) then {
        // Before returning to idle, clean up stale icons
        call GVAR(cleanupStale);
        "idle"
    } else {
        ""
    };
}, {}] call PRA3_fw_addState;

// ======================================================================
// 3. Stale icon cleanup function
// ======================================================================
GVAR(cleanupStale) = {
    // Remove unit icons for units no longer in the seen set
    {
        if !(_x in GVAR(seenUnits)) then {
            deleteMarkerLocal _y;
            GVAR(unitIcons) deleteAt _x;
        };
    } forEach +GVAR(unitIcons);

    // Remove group icons for groups no longer seen
    {
        if !(_x in GVAR(seenGroups)) then {
            deleteMarkerLocal _y;
            GVAR(groupIcons) deleteAt _x;
        };
    } forEach +GVAR(groupIcons);

    // Remove vehicle icons for vehicles no longer seen
    {
        if !(_x in GVAR(seenVehicles)) then {
            deleteMarkerLocal _y;
            GVAR(vehicleIcons) deleteAt _x;
        };
    } forEach +GVAR(vehicleIcons);
};

// ======================================================================
// 4. Start the state machine
// ======================================================================
[_sm, "idle"] call PRA3_fw_startSM;

diag_log "[PRA3 UnitTracker] Client state machine started.";
