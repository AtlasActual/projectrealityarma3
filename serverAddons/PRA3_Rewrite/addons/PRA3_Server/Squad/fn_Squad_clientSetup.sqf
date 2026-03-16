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
private _cfgRoot = missionConfigFile >> "PRA3" >> "CfgSideSwitch";

GVAR(restrictionCount) = getNumber (_cfgRoot >> "restrictionCount");
GVAR(restrictionTime)  = getNumber (_cfgRoot >> "restrictionTime");

// Apply defaults if config values are missing
if (GVAR(restrictionCount) isEqualTo 0) then {
    GVAR(restrictionCount) = 2;
};
if (GVAR(restrictionTime) isEqualTo 0) then {
    GVAR(restrictionTime) = 300;
};

// Timestamp after which the player may switch sides again
GVAR(switchUnlockTime) = 0;

diag_log format [
    "[PRA3 Squad] Client setup complete. Restriction: count=%1, time=%2s",
    GVAR(restrictionCount),
    GVAR(restrictionTime)
];
