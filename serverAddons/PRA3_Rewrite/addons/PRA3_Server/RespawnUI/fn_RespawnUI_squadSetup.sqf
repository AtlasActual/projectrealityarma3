#include "script_component.hpp"
/*
    FUNC(squadSetup)

    Description:
        Initializes the squad management panel within the respawn screen.
        Contains team info display, squad list, squad creation, member list,
        join/leave, kick, promote, and side-switch functionality.

    Control IDs used:
        100 - Team info control group
        102 - Side flag picture
        103 - Side name text
        200 - Squad panel control group
        203 - New squad designator text
        204 - Squad description input field
        205 - Squad type combo box
        207 - Squad ListNBox
        209 - Squad member list header text
        210 - Squad member ListNBox
        211 - Join/Leave button
        212 - Kick button
        213 - Promote button

    Called from the framework client bootstrap on machines with an interface.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// TEAM INFO SECTION (control group 100)
// ======================================================================

[UIVAR(SquadScreen_onLoad), {
    params [["_display", displayNull]];

    uiNamespace setVariable [QGVAR(squadDisplay), _display];
    uiNamespace setVariable [QGVAR(teamInfoDisplay), _display];

    [{
        params ["_display"];
        if (isNull _display) exitWith {};

        // Refresh all squad sub-panels
        [UIVAR(RespawnScreen_TeamInfo_refresh)] call PRA3_fw_fireEvent;
        [UIVAR(RespawnScreen_SquadDesignator_refresh)] call PRA3_fw_fireEvent;
        [UIVAR(RespawnScreen_SquadTypeCombo_refresh)] call PRA3_fw_fireEvent;
        [UIVAR(RespawnScreen_SquadList_refresh)] call PRA3_fw_fireEvent;
        [UIVAR(RespawnScreen_MemberList_refresh)] call PRA3_fw_fireEvent;

        // Slide the team info and squad panels into view
        [_display displayCtrl 100] call FUNC(animateControl);
        [_display displayCtrl 200] call FUNC(animateControl);

    }, [_display]] call PRA3_fw_execNextFrame;
}] call PRA3_fw_addHandler;

// --- Team info refresh: flag and side name ---
[UIVAR(RespawnScreen_TeamInfo_refresh), {
    private _display = uiNamespace getVariable [QGVAR(teamInfoDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _flagPath = missionNamespace getVariable [format [QEGVAR(Common,Flag_%1), playerSide], ""];
    private _sideName = missionNamespace getVariable [format [QEGVAR(Common,sideName_%1), playerSide], ""];

    (_display displayCtrl 102) ctrlSetText _flagPath;
    (_display displayCtrl 103) ctrlSetText _sideName;
}] call PRA3_fw_addHandler;

["playerSideChanged", {
    [UIVAR(RespawnScreen_TeamInfo_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// --- Side switch button ---
[UIVAR(RespawnScreen_ChangeSideBtn_onButtonClick), {
    // Validate that the player is allowed to switch
    private _canSwitch = call EFUNC(Squad,canChangeSide);
    if (!_canSwitch) exitWith {};

    call EFUNC(Squad,changeSide);
}] call PRA3_fw_addHandler;

// ======================================================================
// SQUAD CREATION SECTION
// ======================================================================

// --- Next squad designator letter ---
[UIVAR(RespawnScreen_SquadDesignator_refresh), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    // Determine the next available designator letter
    private _usedLetters = (allGroups select {
        side _x isEqualTo playerSide && {(groupId _x) in EGVAR(Squad,squadIds)}
    }) apply { (groupId _x) select [0, 1] };

    private _alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private _nextLetter = "Z";
    {
        private _letter = _alphabet select [_forEachIndex, 1];
        if !(_letter in _usedLetters) exitWith {
            _nextLetter = _letter;
        };
    } forEach (toArray _alphabet);

    (_display displayCtrl 203) ctrlSetText _nextLetter;
}] call PRA3_fw_addHandler;

["playerSideChanged", {
    [UIVAR(RespawnScreen_SquadDesignator_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

["groupChanged", {
    [UIVAR(RespawnScreen_SquadDesignator_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// --- Squad description input length limiter (14 char max) ---
[UIVAR(RespawnScreen_SquadDescriptionInput_TextChanged), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _inputCtrl = _display displayCtrl 204;
    private _text = ctrlText _inputCtrl;

    if (count _text > 14) then {
        // Flash the background orange briefly to indicate limit reached
        _inputCtrl ctrlSetBackgroundColor [0.77, 0.51, 0.08, 1];
        _inputCtrl ctrlCommit 0;

        [{
            params ["_inputCtrl"];
            _inputCtrl ctrlSetBackgroundColor [0.4, 0.4, 0.4, 1];
            _inputCtrl ctrlCommit 0;
        }, 1, [_inputCtrl]] call PRA3_fw_waitAndExec;

        _inputCtrl ctrlSetText (_text select [0, 14]);
    };
}] call PRA3_fw_addHandler;

// --- Squad type combo box ---
[UIVAR(RespawnScreen_SquadTypeCombo_refresh), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _comboCtrl = _display displayCtrl 205;
    private _previousType = _comboCtrl lbData (lbCurSel _comboCtrl);
    lbClear _comboCtrl;

    private _validTypes = [];
    private _cfgRoot = missionConfigFile >> "PRA3" >> "TeamRoles";

    for "_i" from 0 to (count _cfgRoot - 1) do {
        private _entry = _cfgRoot select _i;
        if (isClass _entry) then {
            private _typeName = configName _entry;

            // Check whether this type is allowed for the current side
            private _allowed = [_typeName] call EFUNC(Squad,typeAllowed);
            if (_allowed) then {
                private _typeLabel = getText (_entry >> "displayName");
                private _row = _comboCtrl lbAdd _typeLabel;
                _comboCtrl lbSetData [_row, _typeName];
                _validTypes pushBack _typeName;

                // Restore previous selection
                if (_typeName isEqualTo _previousType) then {
                    _comboCtrl lbSetCurSel _row;
                };
            };
        };
    };

    // Default to first entry if nothing was selected
    if (lbCurSel _comboCtrl < 0 && {count _validTypes > 0}) then {
        _comboCtrl lbSetCurSel 0;
    };
}] call PRA3_fw_addHandler;

["playerSideChanged", {
    [UIVAR(RespawnScreen_SquadTypeCombo_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

["groupChanged", {
    [UIVAR(RespawnScreen_SquadTypeCombo_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// --- Create squad button ---
[UIVAR(RespawnScreen_CreateSquadBtn_onButtonClick), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    // Read the description from the input field
    private _descCtrl = _display displayCtrl 204;
    private _description = ctrlText _descCtrl;
    if (count _description > 14) then {
        _description = _description select [0, 14];
    };

    // Read the selected group type
    private _typeCtrl = _display displayCtrl 205;
    private _groupType = _typeCtrl lbData (lbCurSel _typeCtrl);

    if (_groupType isEqualTo "") exitWith {};

    // Call the Squad module to create the squad
    [_description, _groupType] call EFUNC(Squad,create);
}] call PRA3_fw_addHandler;

// ======================================================================
// SQUAD LIST SECTION (control 207)
// ======================================================================

[UIVAR(RespawnScreen_SquadList_refresh), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _ownGroupRow = -1;
    private _listData = [];

    // Iterate all groups on the player's side that are registered squads
    private _sideGroups = allGroups select {
        side _x isEqualTo playerSide && {(groupId _x) in EGVAR(Squad,squadIds)}
    };

    {
        private _grp = _x;
        private _grpId = groupId _grp;

        if (_grp isEqualTo group player) then {
            _ownGroupRow = _forEachIndex;
        };

        private _designator = _grpId select [0, 1];
        private _desc = _grp getVariable [QEGVAR(Squad,Description), _grpId];
        private _grpType = _grp getVariable [QEGVAR(Squad,Type), ""];

        // Read type display name and max size from config
        private _typeCfg = missionConfigFile >> "PRA3" >> "TeamRoles" >> _grpType;
        private _typeName = if (isClass _typeCfg) then {
            getText (_typeCfg >> "displayName")
        } else {
            _grpType
        };
        private _maxSize = if (isClass _typeCfg) then {
            getNumber (_typeCfg >> "groupSize")
        } else {
            8
        };

        if (_desc isEqualTo "") then {
            _desc = _grpId;
        };

        private _sizeStr = format ["%1 / %2", count (units _grp), _maxSize];

        _listData pushBack [[_designator, _desc, _typeName, _sizeStr], _grp];
    } forEach _sideGroups;

    // Populate the squad ListNBox
    private _listCtrl = _display displayCtrl 207;
    [_listCtrl, _listData] call FUNC(populateList);

    // Highlight the player's own squad row in orange
    if (_ownGroupRow >= 0) then {
        for "_col" from 0 to 3 do {
            _listCtrl lnbSetColor [[_ownGroupRow, _col], [0.77, 0.51, 0.08, 1]];
        };
    };
}] call PRA3_fw_addHandler;

["playerSideChanged", {
    [UIVAR(RespawnScreen_SquadList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

["groupChanged", {
    [UIVAR(RespawnScreen_SquadList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// SQUAD MEMBER LIST SECTION (controls 209, 210, 211)
// ======================================================================

[UIVAR(RespawnScreen_SquadList_onLBSelChanged), {
    [UIVAR(RespawnScreen_MemberList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

[UIVAR(RespawnScreen_MemberList_refresh), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _squadListCtrl = _display displayCtrl 207;
    private _headerCtrl = _display displayCtrl 209;
    private _memberListCtrl = _display displayCtrl 210;
    private _joinLeaveBtn = _display displayCtrl 211;

    private _selRow = lnbCurSelRow _squadListCtrl;

    // Nothing selected: reset member panel
    if (_selRow < 0) exitWith {
        _headerCtrl ctrlSetText "SELECT A SQUAD";
        lnbClear _memberListCtrl;
        _memberListCtrl lnbSetCurSelRow -1;
        _joinLeaveBtn ctrlShow false;
    };

    // Read the group object stored in the list data
    private _selectedGrp = _squadListCtrl lnbData [_selRow, 0];

    // Look up the actual group object from the data string
    private _grpObj = grpNull;
    {
        if (str _x isEqualTo _selectedGrp || {groupId _x isEqualTo _selectedGrp}) exitWith {
            _grpObj = _x;
        };
    } forEach allGroups;

    if (isNull _grpObj) exitWith {
        _headerCtrl ctrlSetText "SELECT A SQUAD";
        lnbClear _memberListCtrl;
        _joinLeaveBtn ctrlShow false;
    };

    // Set the header to the group ID
    _headerCtrl ctrlSetText toUpper (groupId _grpObj);

    // Build member list data
    private _memberData = (units _grpObj) apply {
        private _unit = _x;
        private _kitName = _unit getVariable [QEGVAR(Kit,currentKit), ""];
        private _kitIcon = "";

        if (_kitName isNotEqualTo "") then {
            // Try to find icon from kit config
            private _allKits = [side _grpObj] call EFUNC(Kit,listAll);
            {
                _x params ["_kName", "_kCfg"];
                if (_kName isEqualTo _kitName) exitWith {
                    private _details = [_kCfg] call EFUNC(Kit,details);
                    _kitIcon = _details getOrDefault ["icon", ""];
                };
            } forEach _allKits;
        };

        if (_kitIcon isEqualTo "") then {
            _kitIcon = "\a3\ui_f\data\IGUI\Cfg\Actions\clear_empty_ca.paa";
        };

        [[name _unit], _unit, _kitIcon]
    };

    [_memberListCtrl, _memberData] call FUNC(populateList);

    // Join/Leave button state
    if (_grpObj isEqualTo group player) then {
        _joinLeaveBtn ctrlSetText "LEAVE";
        _joinLeaveBtn ctrlShow true;
    } else {
        // Show JOIN only if the squad is not full
        private _grpType = _grpObj getVariable [QEGVAR(Squad,Type), ""];
        private _typeCfg = missionConfigFile >> "PRA3" >> "TeamRoles" >> _grpType;
        private _maxSize = if (isClass _typeCfg) then {
            getNumber (_typeCfg >> "groupSize")
        } else {
            8
        };

        _joinLeaveBtn ctrlSetText "JOIN";
        _joinLeaveBtn ctrlShow (count (units _grpObj) < _maxSize);
    };
}] call PRA3_fw_addHandler;

// Kit changes affect member list icons
["kitChanged", {
    [UIVAR(RespawnScreen_MemberList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// MEMBER ACTION BUTTONS (kick 212, promote 213)
// ======================================================================

[UIVAR(RespawnScreen_SquadMemberList_onLBSelChanged), {
    [UIVAR(RespawnScreen_MemberButtons_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

["leaderChanged", {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    // Only refresh buttons if the player's own squad is selected
    private _squadListCtrl = _display displayCtrl 207;
    private _selRow = lnbCurSelRow _squadListCtrl;
    if (_selRow < 0) exitWith {};

    private _selData = _squadListCtrl lnbData [_selRow, 0];
    private _isOwnSquad = false;
    {
        if ((str _x isEqualTo _selData || {groupId _x isEqualTo _selData}) && {_x isEqualTo group player}) exitWith {
            _isOwnSquad = true;
        };
    } forEach allGroups;

    if (_isOwnSquad) then {
        [UIVAR(RespawnScreen_MemberButtons_refresh)] call PRA3_fw_fireEvent;
    };
}] call PRA3_fw_addHandler;

[UIVAR(RespawnScreen_MemberButtons_refresh), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _memberListCtrl = _display displayCtrl 210;
    private _kickBtn = _display displayCtrl 212;
    private _promoteBtn = _display displayCtrl 213;

    private _memberRow = lnbCurSelRow _memberListCtrl;

    if (_memberRow < 0) exitWith {
        _kickBtn ctrlShow false;
        _promoteBtn ctrlShow false;
    };

    // Read the selected unit from stored data
    private _memberData = _memberListCtrl lnbData [_memberRow, 0];

    // Determine if current player is the leader and the selection is a different member
    private _isLeaderOfSelected = false;
    {
        if (str _x isEqualTo _memberData) exitWith {
            _isLeaderOfSelected = (player isEqualTo leader _x) && {player isNotEqualTo _x};
        };
    } forEach (units group player);

    _kickBtn ctrlShow _isLeaderOfSelected;
    _promoteBtn ctrlShow _isLeaderOfSelected;
}] call PRA3_fw_addHandler;

// ======================================================================
// BUTTON CLICK HANDLERS
// ======================================================================

// --- Join/Leave ---
[UIVAR(RespawnScreen_JoinLeaveBtn_onButtonClick), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _listCtrl = _display displayCtrl 207;
    private _selRow = lnbCurSelRow _listCtrl;
    if (_selRow < 0) exitWith {};

    private _selData = _listCtrl lnbData [_selRow, 0];

    // Find the actual group object
    private _targetGrp = grpNull;
    {
        if (str _x isEqualTo _selData || {groupId _x isEqualTo _selData}) exitWith {
            _targetGrp = _x;
        };
    } forEach allGroups;

    if (isNull _targetGrp) exitWith {};

    if (_targetGrp isEqualTo group player) then {
        call EFUNC(Squad,leave);
    } else {
        [_targetGrp] call EFUNC(Squad,join);
    };
}] call PRA3_fw_addHandler;

// --- Kick ---
[UIVAR(RespawnScreen_KickBtn_onButtonClick), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _memberListCtrl = _display displayCtrl 210;
    private _selRow = lnbCurSelRow _memberListCtrl;
    if (_selRow < 0) exitWith {};

    private _memberData = _memberListCtrl lnbData [_selRow, 0];

    // Find the unit object
    private _targetUnit = objNull;
    {
        if (str _x isEqualTo _memberData) exitWith {
            _targetUnit = _x;
        };
    } forEach (units group player);

    if (!isNull _targetUnit) then {
        [_targetUnit] call EFUNC(Squad,kick);
    };
}] call PRA3_fw_addHandler;

// --- Promote ---
[UIVAR(RespawnScreen_PromoteBtn_onButtonClick), {
    private _display = uiNamespace getVariable [QGVAR(squadDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _memberListCtrl = _display displayCtrl 210;
    private _selRow = lnbCurSelRow _memberListCtrl;
    if (_selRow < 0) exitWith {};

    private _memberData = _memberListCtrl lnbData [_selRow, 0];

    // Find the unit object
    private _targetUnit = objNull;
    {
        if (str _x isEqualTo _memberData) exitWith {
            _targetUnit = _x;
        };
    } forEach (units group player);

    if (!isNull _targetUnit) then {
        [_targetUnit] call EFUNC(Squad,promote);
    };
}] call PRA3_fw_addHandler;

diag_log "[PRA3 RespawnUI] Squad setup complete.";
