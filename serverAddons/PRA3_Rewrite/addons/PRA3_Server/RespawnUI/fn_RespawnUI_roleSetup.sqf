#include "script_component.hpp"
/*
    FUNC(roleSetup)

    Description:
        Initializes the role/kit selection panel within the respawn screen.
        Lists kits for the player's side, shows availability counts,
        weapon preview tabs (primary, secondary, special), and stores
        the selected kit config path.

    Control IDs used:
        300 - Role panel control group
        303 - Kit ListNBox
        304 - Weapon tab ToolBox (primary / handgun / launcher)
        306 - Weapon picture
        307 - Weapon name text

    Called from the framework client bootstrap on machines with an interface.
*/

if (!hasInterface) exitWith {};

// Persistent storage for the player's chosen kit config path
GVAR(selectedKit) = "";

// ======================================================================
// 1. Role panel onLoad: populate kit list, animate in
// ======================================================================
[UIVAR(RoleScreen_onLoad), {
    params [["_display", displayNull]];

    uiNamespace setVariable [QGVAR(roleDisplay), _display];

    [{
        params ["_display"];
        if (isNull _display) exitWith {};

        // Populate the kit list for the current side
        [UIVAR(RespawnScreen_RoleList_refresh)] call PRA3_fw_fireEvent;

        // Slide the role panel into view
        [_display displayCtrl 300] call FUNC(animateControl);

    }, [_display]] call PRA3_fw_execNextFrame;
}] call PRA3_fw_addHandler;

// ======================================================================
// 2. Kit list refresh: enumerate kits, show availability
// ======================================================================
[UIVAR(RespawnScreen_RoleList_refresh), {
    private _display = uiNamespace getVariable [QGVAR(roleDisplay), displayNull];
    if (isNull _display) exitWith {};

    // Fetch all kits for the player's current side
    private _allKits = [playerSide] call EFUNC(Kit,listAll);

    private _listData = [];
    {
        _x params ["_kitClassName", "_kitConfig"];

        // Check how many slots remain for this kit
        private _slotsLeft = [_kitConfig] call EFUNC(Kit,availability);

        if (_slotsLeft > 0) then {
            // Read display name and icon from the kit config
            private _detailMap = [_kitConfig] call EFUNC(Kit,details);
            private _displayName = _detailMap getOrDefault ["displayName", _kitClassName];
            private _icon = _detailMap getOrDefault ["icon", ""];

            // Count how many squad members already use this kit
            private _usedInSquad = {
                (_x getVariable [QEGVAR(Kit,currentKit), ""]) isEqualTo _kitClassName
            } count (units group player);

            // Build the label with availability info
            private _label = format ["%1 [%2/%3]", _displayName, _usedInSquad, _slotsLeft + _usedInSquad];

            _listData pushBack [[_label], _kitClassName, _icon];
        };
    } forEach _allKits;

    // Populate the ListNBox, attempting to keep the previously selected kit
    private _currentKit = player getVariable [QEGVAR(Kit,currentKit), ""];
    [_display displayCtrl 303, _listData, _currentKit] call FUNC(populateList);
}] call PRA3_fw_addHandler;

// ======================================================================
// 3. Refresh availability when group or leader changes
// ======================================================================
["groupChanged", {
    [UIVAR(RespawnScreen_RoleList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

["leaderChanged", {
    [UIVAR(RespawnScreen_RoleList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// 4. Kit selection changed: store selection, refresh for squad, update tabs
// ======================================================================
[UIVAR(RespawnScreen_RoleList_onLBSelChanged), {
    private _display = uiNamespace getVariable [QGVAR(roleDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _listCtrl = _display displayCtrl 303;
    private _selRow = lnbCurSelRow _listCtrl;
    if (_selRow < 0) exitWith {};

    private _chosenKit = _listCtrl lnbData [_selRow, 0];
    private _previousKit = player getVariable [QEGVAR(Kit,currentKit), ""];

    // Only act if the selection actually changed
    if (_chosenKit isNotEqualTo _previousKit) then {
        // Store the kit assignment (publicVariable so squad sees it)
        player setVariable [QEGVAR(Kit,currentKit), _chosenKit, true];
        GVAR(selectedKit) = _chosenKit;

        // Refresh the list on all group members so counts update
        [UIVAR(RespawnScreen_RoleList_refresh)] call PRA3_fw_fireEvent;
    } else {
        // Same kit re-selected: just refresh the weapon preview tabs
        [UIVAR(RespawnScreen_WeaponTabs_refresh)] call PRA3_fw_fireEvent;
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// 5. Weapon tab selection changed: refresh the weapon preview
// ======================================================================
[UIVAR(RespawnScreen_WeaponTabs_onToolBoxSelChanged), {
    [UIVAR(RespawnScreen_WeaponTabs_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// 6. Weapon tabs content update: show picture and name for selected tab
// ======================================================================
[UIVAR(RespawnScreen_WeaponTabs_refresh), {
    private _display = uiNamespace getVariable [QGVAR(roleDisplay), displayNull];
    if (isNull _display) exitWith {};

    // Determine which kit is selected in the list
    private _listCtrl = _display displayCtrl 303;
    private _selRow = lnbCurSelRow _listCtrl;
    if (_selRow < 0) exitWith {};

    private _chosenKit = _listCtrl lnbData [_selRow, 0];

    // Determine which weapon tab is active (0=primary, 1=handgun, 2=launcher)
    private _tabIndex = lbCurSel (_display displayCtrl 304);
    private _weaponKeys = ["weapons", "weapons", "weapons"];
    private _tabSlots = ["primaryWeapon", "handGunWeapon", "secondaryWeapon"];
    private _slotKey = _tabSlots select (_tabIndex max 0 min 2);

    // Find the kit config and read the weapon classname for the chosen slot
    private _allKits = [playerSide] call EFUNC(Kit,listAll);
    private _weaponClass = "";

    {
        _x params ["_kitName", "_kitConfig"];
        if (_kitName isEqualTo _chosenKit) exitWith {
            private _detailMap = [_kitConfig] call EFUNC(Kit,details);
            private _allWeapons = _detailMap getOrDefault ["weapons", []];

            // Look through weapons to find one matching the slot
            {
                private _wepCfg = configFile >> "CfgWeapons" >> _x;
                if (isClass _wepCfg) then {
                    private _type = getNumber (_wepCfg >> "type");
                    // type 1 = primary, type 2 = handgun, type 4 = launcher
                    private _matchSlot = switch (_tabIndex) do {
                        case 0: { _type isEqualTo 1 };
                        case 1: { _type isEqualTo 2 };
                        case 2: { _type isEqualTo 4 };
                        default { false };
                    };
                    if (_matchSlot && {_weaponClass isEqualTo ""}) then {
                        _weaponClass = _x;
                    };
                };
            } forEach _allWeapons;
        };
    } forEach _allKits;

    // Update weapon picture (306) and weapon name (307)
    if (_weaponClass isNotEqualTo "") then {
        private _wepCfg = configFile >> "CfgWeapons" >> _weaponClass;
        (_display displayCtrl 306) ctrlSetText getText (_wepCfg >> "picture");
        (_display displayCtrl 307) ctrlSetText getText (_wepCfg >> "displayName");
    } else {
        (_display displayCtrl 306) ctrlSetText "";
        (_display displayCtrl 307) ctrlSetText "";
    };
}] call PRA3_fw_addHandler;

diag_log "[PRA3 RespawnUI] Role setup complete.";
