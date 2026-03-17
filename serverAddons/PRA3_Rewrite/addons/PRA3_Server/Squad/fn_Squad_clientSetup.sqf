#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side squad module initialisation. Loads group type
        settings from the mission config, defines the NATO phonetic
        alphabet squad name pool, and reads side-switch restriction
        parameters.

    Called from the Squad init sequence on machines with an interface.
*/

if (!hasInterface) exitWith {};

// Initialize the tracked squad IDs registry (tracks which groups are PRA3 squads)
if (isNil QGVAR(squadIds)) then {
    GVAR(squadIds) = [];
};

// ======================================================================
// 1. Load group type configuration from mission config
// ======================================================================
[QGVAR(groupTypes), "PRA3 >> TeamRoles"] call PRA3_fw_loadSettings;

diag_log format [
    "[PRA3 Squad] Group type settings loaded: %1 types",
    count (missionNamespace getVariable [QGVAR(groupTypes), createHashMap])
];

// ======================================================================
// 2. Define squad name pool (NATO phonetic alphabet)
// ======================================================================
GVAR(squadNames) = [
    "Alpha",
    "Bravo",
    "Charlie",
    "Delta",
    "Echo",
    "Foxtrot",
    "Golf",
    "Hotel",
    "India",
    "Juliet",
    "Kilo",
    "Lima",
    "Mike",
    "November",
    "Oscar",
    "Papa",
    "Quebec",
    "Romeo",
    "Sierra",
    "Tango",
    "Uniform",
    "Victor",
    "Whiskey",
    "X-ray",
    "Yankee",
    "Zulu"
];

// ======================================================================
// 3. Side-switch restriction settings
// ======================================================================
private _cfgRoot = missionConfigFile >> "PRA3" >> "GameRules";

if (isNumber (_cfgRoot >> "restrictSideSwitchRestrictionCount")) then {
    GVAR(restrictionCount) = getNumber (_cfgRoot >> "restrictSideSwitchRestrictionCount");
} else {
    GVAR(restrictionCount) = 2;
};
if (isNumber (_cfgRoot >> "restrictSideSwitchRestrictionTime")) then {
    GVAR(restrictionTime) = getNumber (_cfgRoot >> "restrictSideSwitchRestrictionTime");
} else {
    GVAR(restrictionTime) = 300;
};

// Timestamp after which the player may switch sides again
GVAR(switchUnlockTime) = 0;

diag_log format [
    "[PRA3 Squad] Client setup complete. Restriction: count=%1, time=%2s",
    GVAR(restrictionCount),
    GVAR(restrictionTime)
];
