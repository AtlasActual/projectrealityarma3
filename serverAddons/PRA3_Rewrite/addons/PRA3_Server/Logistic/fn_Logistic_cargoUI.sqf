#include "script_component.hpp"
/*
    FUNC(cargoUI)

    Description:
        Custom cargo inventory UI overlay. When the player opens an
        inventory display near a logistic vehicle, this script injects
        a cargo listbox, an unload button, and a capacity progress bar
        into the display. Refreshes automatically when the underlying
        cargo data changes.

    Called from clientSetup or via display event handler.
*/

if (!hasInterface) exitWith {};

// IDC constants for the injected controls
#define IDC_CARGO_LIST    48701
#define IDC_CARGO_UNLOAD  48702
#define IDC_CARGO_BAR_BG  48703
#define IDC_CARGO_BAR_FG  48704
#define IDC_CARGO_LABEL   48705

// ======================================================================
// 1. Monitor for inventory display opening
// ======================================================================
GVAR(cargoUIPFH) = [{
    params ["_args", "_pfhId"];

    // The standard inventory display IDD is 602
    private _display = findDisplay 602;
    if (isNull _display) exitWith {
        // Clean up if we had a previous overlay active
        if (!isNil QGVAR(cargoUIActive)) then {
            GVAR(cargoUIActive) = nil;
        };
    };

    // Determine if the player is near a logistic vehicle
    private _nearVehicles = nearestObjects [player, GVAR(cargoClasses), 8];
    private _targetVeh = objNull;

    {
        if (_x getVariable [QGVAR(hasInventory), false]) exitWith {
            _targetVeh = _x;
        };
    } forEach _nearVehicles;

    if (isNull _targetVeh) exitWith {
        // Hide overlay if no logistic vehicle nearby
        private _existingList = _display displayCtrl IDC_CARGO_LIST;
        if (!isNull _existingList) then {
            _existingList ctrlShow false;
            (_display displayCtrl IDC_CARGO_UNLOAD) ctrlShow false;
            (_display displayCtrl IDC_CARGO_BAR_BG) ctrlShow false;
            (_display displayCtrl IDC_CARGO_BAR_FG) ctrlShow false;
            (_display displayCtrl IDC_CARGO_LABEL) ctrlShow false;
        };
    };

    // Create overlay controls once per display session
    if (isNil QGVAR(cargoUIActive) || {!(GVAR(cargoUIActive) isEqualTo _display)}) then {
        GVAR(cargoUIActive) = _display;

        // -- Cargo label
        private _label = _display ctrlCreate ["RscText", IDC_CARGO_LABEL];
        _label ctrlSetPosition [
            safezoneX + safezoneW * 0.73,
            safezoneY + safezoneH * 0.25,
            safezoneW * 0.22,
            safezoneH * 0.03
        ];
        _label ctrlSetText "Vehicle Cargo:";
        _label ctrlSetTextColor [1, 1, 1, 1];
        _label ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
        _label ctrlCommit 0;

        // -- Cargo listbox
        private _listBox = _display ctrlCreate ["RscListBox", IDC_CARGO_LIST];
        _listBox ctrlSetPosition [
            safezoneX + safezoneW * 0.73,
            safezoneY + safezoneH * 0.28,
            safezoneW * 0.22,
            safezoneH * 0.25
        ];
        _listBox ctrlSetBackgroundColor [0.05, 0.05, 0.05, 0.85];
        _listBox ctrlCommit 0;

        // -- Capacity bar background
        private _barBg = _display ctrlCreate ["RscText", IDC_CARGO_BAR_BG];
        _barBg ctrlSetPosition [
            safezoneX + safezoneW * 0.73,
            safezoneY + safezoneH * 0.54,
            safezoneW * 0.22,
            safezoneH * 0.02
        ];
        _barBg ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.9];
        _barBg ctrlCommit 0;

        // -- Capacity bar foreground (filled portion)
        private _barFg = _display ctrlCreate ["RscText", IDC_CARGO_BAR_FG];
        _barFg ctrlSetPosition [
            safezoneX + safezoneW * 0.73,
            safezoneY + safezoneH * 0.54,
            0,
            safezoneH * 0.02
        ];
        _barFg ctrlSetBackgroundColor [0.3, 0.7, 0.2, 0.9];
        _barFg ctrlCommit 0;

        // -- Unload button
        private _btn = _display ctrlCreate ["RscButton", IDC_CARGO_UNLOAD];
        _btn ctrlSetPosition [
            safezoneX + safezoneW * 0.73,
            safezoneY + safezoneH * 0.57,
            safezoneW * 0.22,
            safezoneH * 0.04
        ];
        _btn ctrlSetText "Unload Selected";
        _btn ctrlSetBackgroundColor [0.6, 0.15, 0.15, 0.85];
        _btn ctrlCommit 0;

        // Button click handler — unloads the selected cargo item
        _btn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _display  = ctrlParent _ctrl;
            private _listBox  = _display displayCtrl IDC_CARGO_LIST;
            private _selIdx   = lbCurSel _listBox;

            if (_selIdx < 0) exitWith {
                systemChat "Select a cargo item to unload.";
            };

            private _netId = _listBox lbData _selIdx;
            if (_netId == "") exitWith {};

            // Find the vehicle
            private _nearVehs = nearestObjects [player, GVAR(cargoClasses), 8];
            private _veh = objNull;
            {
                if (_x getVariable [QGVAR(hasInventory), false]) exitWith {
                    _veh = _x;
                };
            } forEach _nearVehs;

            if (isNull _veh) exitWith {
                systemChat "No cargo vehicle nearby.";
            };

            private _loaded = _veh getVariable [QGVAR(cargoLoaded), []];
            private _rmIdx = _loaded find _netId;

            if (_rmIdx < 0) exitWith {
                systemChat "Item not found in cargo.";
            };

            _loaded deleteAt _rmIdx;
            _veh setVariable [QGVAR(cargoLoaded), _loaded, true];

            private _cargoObj = objectFromNetId _netId;
            if (!isNull _cargoObj) then {
                private _dropDir  = (getDir _veh) + 180;
                private _vehPos   = getPosATL _veh;
                private _dropPos  = [
                    (_vehPos select 0) + (4 * sin _dropDir),
                    (_vehPos select 1) + (4 * cos _dropDir),
                    0
                ];
                private _safePos = [_dropPos, 10] call PRA3_fw_safePos;

                [_cargoObj, false] remoteExec ["hideObjectGlobal", 2];
                [_cargoObj, true] remoteExec ["enableSimulationGlobal", 2];
                _cargoObj setPosATL [_safePos select 0, _safePos select 1, 0];

                systemChat format ["Unloaded %1.", typeOf _cargoObj];
            };
        }];
    };

    // ======================================================================
    // 2. Refresh the listbox and capacity bar every frame
    // ======================================================================
    private _listBox = _display displayCtrl IDC_CARGO_LIST;
    private _barFg   = _display displayCtrl IDC_CARGO_BAR_FG;
    private _label   = _display displayCtrl IDC_CARGO_LABEL;

    if (isNull _listBox) exitWith {};

    private _loaded   = _targetVeh getVariable [QGVAR(cargoLoaded), []];
    private _capacity = _targetVeh getVariable [QGVAR(cargoCapacity), 4];

    // Only rebuild listbox when cargo count has changed
    private _prevCount = _targetVeh getVariable [QGVAR(uiPrevCount), -1];

    if (count _loaded != _prevCount) then {
        _targetVeh setVariable [QGVAR(uiPrevCount), count _loaded];

        lbClear _listBox;

        {
            private _cargoObj = objectFromNetId _x;
            private _dispName = if (!isNull _cargoObj) then {
                private _cfgName = getText (configFile >> "CfgVehicles" >> typeOf _cargoObj >> "displayName");
                if (_cfgName != "") then { _cfgName } else { typeOf _cargoObj };
            } else {
                format ["<Unknown: %1>", _x]
            };

            private _idx = _listBox lbAdd _dispName;
            _listBox lbSetData [_idx, _x];
        } forEach _loaded;
    };

    // Update capacity bar
    private _fillRatio = if (_capacity > 0) then {
        (count _loaded) / _capacity
    } else {
        0
    };

    private _maxWidth = safezoneW * 0.22;
    _barFg ctrlSetPosition [
        safezoneX + safezoneW * 0.73,
        safezoneY + safezoneH * 0.54,
        _maxWidth * (0 max _fillRatio min 1),
        safezoneH * 0.02
    ];

    // Colour shifts from green to red as capacity fills
    private _r = 0.3 + (_fillRatio * 0.7);
    private _g = 0.7 - (_fillRatio * 0.5);
    _barFg ctrlSetBackgroundColor [_r, _g, 0.2, 0.9];
    _barFg ctrlCommit 0;

    // Update label with count
    _label ctrlSetText format ["Vehicle Cargo: %1 / %2", count _loaded, _capacity];

}, 0.25, []] call PRA3_fw_addPFH;

diag_log "[PRA3 Logistic] Cargo UI monitor started.";
