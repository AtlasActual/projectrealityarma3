#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side Logistic module initialisation. Reads logistic
        configuration from missionConfigFile to build draggable class
        lists and cargo/crate class lists per side. Registers "Spawn
        Crate" addActions on appropriate objects and initialises the
        carrying state tracker.

    Called once on each client after mission init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Initialise carrying state
// ======================================================================
GVAR(isCarrying)    = false;
GVAR(carriedObject) = objNull;

// ======================================================================
// 2. Read logistic configuration from mission config per side
// ======================================================================
GVAR(draggableClasses) = [];
GVAR(cargoClasses)     = [];
GVAR(crateDefinitions) = createHashMap;

private _cfgSides = missionConfigFile >> "PRA3" >> "Sides";

if (!isNull _cfgSides) then {
    for "_i" from 0 to (count _cfgSides - 1) do {
        private _sideCfg = _cfgSides select _i;
        if (!isClass _sideCfg) then { continue };

        private _logCfg = _sideCfg >> "CfgLogistic";
        if (isNull _logCfg) then { continue };

        // Parse draggable classes
        private _dragArr = getArray (_logCfg >> "draggableClasses");
        {
            if !(_x in GVAR(draggableClasses)) then {
                GVAR(draggableClasses) pushBack _x;
            };
        } forEach _dragArr;

        // Parse cargo vehicle classes
        private _cargoArr = getArray (_logCfg >> "cargoClasses");
        {
            if !(_x in GVAR(cargoClasses)) then {
                GVAR(cargoClasses) pushBack _x;
            };
        } forEach _cargoArr;

        // Parse crate definitions for this side
        private _sideName = configName _sideCfg;
        private _cratesNode = _logCfg >> "Crates";
        if (!isNull _cratesNode) then {
            for "_j" from 0 to (count _cratesNode - 1) do {
                private _crateCfg = _cratesNode select _j;
                if (!isClass _crateCfg) then { continue };

                private _crateClass = configName _crateCfg;
                private _crateLabel = getText (_crateCfg >> "displayName");
                if (_crateLabel == "") then {
                    _crateLabel = _crateClass;
                };

                GVAR(crateDefinitions) set [
                    format ["%1_%2", _sideName, _crateClass],
                    [_crateClass, _crateLabel, _sideName]
                ];
            };
        };
    };
};

diag_log format [
    "[PRA3 Logistic] Config loaded — %1 draggable classes, %2 cargo classes, %3 crate defs",
    count GVAR(draggableClasses),
    count GVAR(cargoClasses),
    count GVAR(crateDefinitions)
];

// ======================================================================
// 3. Register "Spawn Crate" addAction on crate spawner objects
// ======================================================================
private _playerSideName = switch (playerSide) do {
    case west:       { "west" };
    case east:       { "east" };
    case resistance: { "resistance" };
    default          { "" };
};

if (_playerSideName != "") then {
    private _spawnCfg = missionConfigFile >> "PRA3" >> "Sides" >> _playerSideName >> "CfgLogistic";

    if (!isNull _spawnCfg) then {
        private _spawnerClasses = getArray (_spawnCfg >> "crateSpawnerClasses");

        {
            private _spawnerObj = _x;
            private _cratesNode = _spawnCfg >> "Crates";

            if (!isNull _cratesNode) then {
                for "_k" from 0 to (count _cratesNode - 1) do {
                    private _crateCfg = _cratesNode select _k;
                    if (!isClass _crateCfg) then { continue };

                    private _crateClass = configName _crateCfg;
                    private _crateLabel = getText (_crateCfg >> "displayName");
                    if (_crateLabel == "") then { _crateLabel = _crateClass; };

                    _spawnerObj addAction [
                        format ["<t color='#8BC34A'>Spawn %1</t>", _crateLabel],
                        {
                            params ["_target", "_caller", "_actionId", "_args"];
                            _args params ["_crateClass", "_sideStr"];

                            private _spawnPos = (getPosATL _target) vectorAdd [
                                (random 4) - 2,
                                (random 4) - 2,
                                0
                            ];

                            private _sideVal = switch (toLower _sideStr) do {
                                case "west":       { west };
                                case "east":       { east };
                                case "resistance": { resistance };
                                default            { civilian };
                            };

                            ["spawnCrate", [_crateClass, _spawnPos, _sideVal]] call PRA3_fw_fireServer;

                            systemChat format ["Requesting %1 supply crate...", _crateClass];
                        },
                        [_crateClass, _playerSideName],
                        4,
                        true,
                        true,
                        "",
                        "alive _originalTarget && {_this distance _originalTarget < 5}"
                    ];
                };
            };
        } forEach (entities [[], [], true, true] select {
            private _ent = _x;
            private _matched = false;
            {
                if (_ent isKindOf _x) exitWith { _matched = true; };
            } forEach _spawnerClasses;
            _matched
        });
    };
};

// ======================================================================
// 4. Set up logistic interaction actions
// ======================================================================
[] call FUNC(actionsSetup);

diag_log "[PRA3 Logistic] Client setup complete.";
