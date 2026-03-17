#include "script_component.hpp"
/*
    FUNC(actionsSetup)

    Description:
        Registers the four core logistic interaction actions on the
        player: Grab/Drag, Drop/Release, Load into Vehicle, and
        Unload from Vehicle. Each action has its own visibility
        condition and mutex protection where appropriate.

    Called from clientSetup.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Grab / Drag — addAction on player targeting nearby draggable objects
// ======================================================================
GVAR(grabActionId) = player addAction [
    "<t color='#FFC107'>Grab Object</t>",
    {
        params ["_target", "_caller", "_actionId"];

        // Find the nearest draggable object within 3 metres
        private _candidates = nearestObjects [_caller, GVAR(draggableClasses), 3];
        private _best = objNull;

        {
            // Skip objects already attached to another player
            if (isNull (attachedTo _x)) exitWith {
                _best = _x;
            };
        } forEach _candidates;

        if (isNull _best) exitWith {
            systemChat "No draggable object nearby.";
        };

        // Mutex-protected grab
        [
            QGVAR(grabMutex),
            {
                params ["_unit", "_obj"];
                [_unit, _obj] call FUNC(grab);
            },
            [_caller, _best],
            _caller
        ] call PRA3_fw_mutexLock;
    },
    nil,
    6,
    false,
    true,
    "",
    format [
        "alive _this && {vehicle _this == _this} && {!(%1)} && {count (nearestObjects [_this, %2, 3] select {isNull (attachedTo _x)}) > 0}",
        QGVAR(isCarrying),
        str GVAR(draggableClasses)
    ]
];

// ======================================================================
// 2. Drop / Release — addAction while player is carrying
// ======================================================================
GVAR(releaseActionId) = player addAction [
    "<t color='#FF5722'>Drop Object</t>",
    {
        params ["_target", "_caller"];
        [_caller] call FUNC(release);
    },
    nil,
    6,
    false,
    true,
    "",
    QGVAR(isCarrying)
];

// ======================================================================
// 3. Load into Vehicle — addAction targeting nearby cargo vehicles
// ======================================================================
GVAR(loadActionId) = player addAction [
    "<t color='#2196F3'>Load into Vehicle</t>",
    {
        params ["_target", "_caller"];

        // Find the nearest cargo-capable vehicle within 5 metres
        private _vehicles = nearestObjects [_caller, GVAR(cargoClasses), 5];
        private _vehicle = objNull;

        {
            if (_x getVariable [QGVAR(hasInventory), false]) exitWith {
                _vehicle = _x;
            };
        } forEach _vehicles;

        if (isNull _vehicle) exitWith {
            systemChat "No cargo vehicle nearby.";
        };

        // Check cargo capacity
        private _capacity   = _vehicle getVariable [QGVAR(cargoCapacity), 4];
        private _loadedList = _vehicle getVariable [QGVAR(cargoLoaded), []];

        if (count _loadedList >= _capacity) exitWith {
            systemChat format ["Vehicle is full (%1/%2 slots used).", count _loadedList, _capacity];
        };

        // Mutex-protected load operation
        [
            QGVAR(loadMutex),
            {
                params ["_unit", "_veh"];

                private _carried = GVAR(carriedObject);
                if (isNull _carried) exitWith {
                    systemChat "You are not carrying anything.";
                };

                // Release from player first
                [_unit] call FUNC(release);

                // Hide and disable the object
                [_carried, true] remoteExec ["hideObjectGlobal", 2];
                [_carried, false] remoteExec ["enableSimulationGlobal", 2];
                _carried setPosATL [0, 0, 0];

                // Register in vehicle cargo
                private _loaded = _veh getVariable [QGVAR(cargoLoaded), []];
                _loaded pushBack (netId _carried);
                _veh setVariable [QGVAR(cargoLoaded), _loaded, true];

                systemChat format [
                    "Loaded %1 into %2 (%3/%4).",
                    typeOf _carried,
                    typeOf _veh,
                    count _loaded,
                    _veh getVariable [QGVAR(cargoCapacity), 4]
                ];

                diag_log format [
                    "[PRA3 Logistic] Loaded %1 into %2",
                    netId _carried, netId _veh
                ];
            },
            [_caller, _vehicle],
            _caller
        ] call PRA3_fw_mutexLock;
    },
    nil,
    5,
    false,
    true,
    "",
    format [
        "alive _this && {vehicle _this == _this} && {%1} && {count (nearestObjects [_this, %2, 5] select {_x getVariable ['%3', false]}) > 0}",
        QGVAR(isCarrying),
        str GVAR(cargoClasses),
        QGVAR(hasInventory)
    ]
];

// ======================================================================
// 4. Unload from Vehicle — addAction on nearby vehicles with cargo
// ======================================================================
GVAR(unloadActionId) = player addAction [
    "<t color='#9C27B0'>Unload from Vehicle</t>",
    {
        params ["_target", "_caller"];

        // Find nearest vehicle with cargo
        private _vehicles = nearestObjects [_caller, GVAR(cargoClasses), 5];
        private _vehicle = objNull;

        {
            private _loaded = _x getVariable [QGVAR(cargoLoaded), []];
            if (count _loaded > 0) exitWith {
                _vehicle = _x;
            };
        } forEach _vehicles;

        if (isNull _vehicle) exitWith {
            systemChat "No vehicle with cargo nearby.";
        };

        // Mutex-protected unload
        [
            QGVAR(unloadMutex),
            {
                params ["_unit", "_veh"];

                private _loaded = _veh getVariable [QGVAR(cargoLoaded), []];
                if (count _loaded == 0) exitWith {
                    systemChat "Vehicle has no cargo to unload.";
                };

                // Remove the last loaded item (LIFO order)
                private _itemNetId = _loaded deleteAt (count _loaded - 1);
                _veh setVariable [QGVAR(cargoLoaded), _loaded, true];

                private _cargoObj = objectFromNetId _itemNetId;
                if (isNull _cargoObj) exitWith {
                    systemChat "Cargo item no longer exists.";
                };

                // Place near the vehicle on the ground
                private _dropDir   = (getDir _veh) + 90;
                private _dropDist  = 3;
                private _vehPos    = getPosATL _veh;
                private _dropPos   = [
                    (_vehPos select 0) + (_dropDist * sin _dropDir),
                    (_vehPos select 1) + (_dropDist * cos _dropDir),
                    0
                ];

                private _safePos = [_dropPos, 10] call PRA3_fw_safePos;

                [_cargoObj, false] remoteExec ["hideObjectGlobal", 2];
                [_cargoObj, true] remoteExec ["enableSimulationGlobal", 2];
                _cargoObj setPosATL [_safePos select 0, _safePos select 1, 0];

                systemChat format [
                    "Unloaded %1 from %2 (%3/%4 remaining).",
                    typeOf _cargoObj,
                    typeOf _veh,
                    count _loaded,
                    _veh getVariable [QGVAR(cargoCapacity), 4]
                ];

                diag_log format [
                    "[PRA3 Logistic] Unloaded %1 from %2",
                    _itemNetId, netId _veh
                ];
            },
            [_caller, _vehicle],
            _caller
        ] call PRA3_fw_mutexLock;
    },
    nil,
    5,
    false,
    true,
    "",
    format [
        "alive _this && {vehicle _this == _this} && {!(%1)} && {count (nearestObjects [_this, %2, 5] select {count (_x getVariable ['%3', []]) > 0}) > 0}",
        QGVAR(isCarrying),
        str GVAR(cargoClasses),
        QGVAR(cargoLoaded)
    ]
];

diag_log "[PRA3 Logistic] Actions setup complete.";
