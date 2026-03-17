#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Description:
        Server-only sector initialisation. Fires after "missionStarted"
        with a 3-second delay. Reads sector definitions from the mission
        config, creates logic units for each sector, resolves dependencies,
        and signals readiness to all clients.

    Called from FUNC(init) on the server.
*/

if (!isServer) exitWith {};

["missionStarted", {
    // Delay 3 seconds so all machines finish preInit
    [{
        // ==============================================================
        // 1. Create master storage logic and sector list
        // ==============================================================
        private _logicGrp = [] call PRA3_fw_getLogicGroup;
        GVAR(masterObj) = _logicGrp createUnit ["Logic", [0, 0, 0], [], 0, "NONE"];
        GVAR(sectorList) = [];
        GVAR(activePFHs) = createHashMap;
        GVAR(sectorUnits) = createHashMap;

        diag_log "[PRA3 Sector] Server setup: reading ObjectiveZones.";

        // ==============================================================
        // 2. Read sector config from mission file
        // ==============================================================
        private _cfgRoot = missionConfigFile >> "PRA3" >> "ObjectiveZones";
        if (isNull _cfgRoot) exitWith {
            diag_log "[PRA3 Sector] ERROR: missionConfigFile >> PRA3 >> ObjectiveZones not found.";
        };

        // Separate base paths from regular sector paths
        private _sectorPaths = [];
        private _basePaths = [];

        for "_i" from 0 to (count _cfgRoot - 1) do {
            private _entry = _cfgRoot select _i;
            if (isClass _entry) then {
                private _name = configName _entry;
                if (toLower _name find "base" >= 0) then {
                    _basePaths pushBack _name;
                } else {
                    _sectorPaths pushBack _name;
                };
            };
        };

        // ==============================================================
        // 3. Process base sectors first (always loaded)
        // ==============================================================
        {
            private _pathCfg = _cfgRoot >> _x;
            [_pathCfg] call DFUNC(processSectorPath);
        } forEach _basePaths;

        // ==============================================================
        // 4. Randomly select one non-base sector path
        // ==============================================================
        if (count _sectorPaths > 0) then {
            private _chosenPath = selectRandom _sectorPaths;
            diag_log format ["[PRA3 Sector] Selected sector path: %1", _chosenPath];
            private _pathCfg = _cfgRoot >> _chosenPath;
            [_pathCfg] call DFUNC(processSectorPath);
        };

        // ==============================================================
        // 5. Resolve initial dependencies and activate sectors
        // ==============================================================
        [] call FUNC(refreshDependencies);

        // ==============================================================
        // 6. Signal readiness to all machines
        // ==============================================================
        GVAR(setupDone) = true;
        publicVariable QGVAR(setupDone);
        publicVariable QGVAR(sectorList);

        diag_log format ["[PRA3 Sector] Setup complete. %1 sectors created.", count GVAR(sectorList)];

        // ==============================================================
        // 7. Register enter/leave tracking handlers
        // ==============================================================
        ["sectorEntered", {
            params ["_unit", "_sector"];

            private _sectorName = _sector getVariable [QGVAR(name), ""];
            if (_sectorName isEqualTo "") exitWith {};

            private _unitSide = side group _unit;
            private _tracked = GVAR(sectorUnits) getOrDefault [_sectorName, createHashMap];
            private _sideUnits = _tracked getOrDefault [_unitSide, []];
            _sideUnits pushBackUnique _unit;
            _tracked set [_unitSide, _sideUnits];
            GVAR(sectorUnits) set [_sectorName, _tracked];
        }] call PRA3_fw_addHandler;

        ["sectorLeft", {
            params ["_unit", "_sector"];

            private _sectorName = _sector getVariable [QGVAR(name), ""];
            if (_sectorName isEqualTo "") exitWith {};

            private _unitSide = side group _unit;
            private _tracked = GVAR(sectorUnits) getOrDefault [_sectorName, createHashMap];
            private _sideUnits = _tracked getOrDefault [_unitSide, []];
            private _idx = _sideUnits find _unit;
            if (_idx >= 0) then {
                _sideUnits deleteAt _idx;
            };
            _tracked set [_unitSide, _sideUnits];
            GVAR(sectorUnits) set [_sectorName, _tracked];
        }] call PRA3_fw_addHandler;

        // ==============================================================
        // 8. Listen for ownership changes to refresh dependency graph
        // ==============================================================
        ["sectorOwnerChanged", {
            [] call FUNC(refreshDependencies);
        }] call PRA3_fw_addHandler;

    }, 3] call PRA3_fw_waitAndExec;
}] call PRA3_fw_addHandler;

// ======================================================================
// Helper: process all sector entries under one config path class
// ======================================================================
DFUNC(processSectorPath) = {
    params ["_pathCfg"];

    for "_i" from 0 to (count _pathCfg - 1) do {
        private _sectorCfg = _pathCfg select _i;
        if (!isClass _sectorCfg) then { continue };

        private _markerName   = getText  (_sectorCfg >> "marker");
        private _dependencies = getArray (_sectorCfg >> "dependency");
        private _ticketValue  = getNumber (_sectorCfg >> "ticketValue");
        private _minUnits     = getNumber (_sectorCfg >> "minUnits");
        private _maxUnits     = getNumber (_sectorCfg >> "maxUnits");
        private _captureTime  = getArray  (_sectorCfg >> "captureTime");
        private _firstCapTime = getArray  (_sectorCfg >> "firstCaptureTime");
        private _designator   = getText  (_sectorCfg >> "designator");

        // Apply defaults for missing config entries
        if (_markerName isEqualTo "") then {
            _markerName = configName _sectorCfg;
        };
        if (_ticketValue isEqualTo 0) then {
            _ticketValue = 10;
        };
        if (_minUnits isEqualTo 0) then {
            _minUnits = 1;
        };
        if (_maxUnits isEqualTo 0) then {
            _maxUnits = 8;
        };
        if (_captureTime isEqualTo []) then {
            _captureTime = [60, 120];
        };
        if (_firstCapTime isEqualTo []) then {
            _firstCapTime = [30, 60];
        };
        if (_designator isEqualTo "") then {
            _designator = configName _sectorCfg;
        };

        [
            _markerName,
            _dependencies,
            _ticketValue,
            _minUnits,
            _maxUnits,
            _captureTime,
            _firstCapTime,
            _designator
        ] call FUNC(createLogic);
    };
};
