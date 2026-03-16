#include "script_component.hpp"
/*
    FUNC(availability)

    Description:
        Checks how many remaining slots are available for a given kit.
        Accounts for kitGroup membership, maxPerSquad, and maxPerTeam
        restrictions. Returns the number of remaining slots (0 = unavailable).

    Params:
        0: _kitConfig - CONFIG - config path to the kit entry

    Returns:
        NUMBER - remaining available slots (0 means kit is not available)
*/

params ["_kitConfig"];

private _kitDetails = [_kitConfig] call FUNC(details);
private _kitClassName = configName _kitConfig;
private _kitGroup = _kitDetails get "kitGroup";
private _maxPerSquad = _kitDetails get "maxPerSquad";
private _maxPerTeam = _kitDetails get "maxPerTeam";

// If no restrictions defined, always available
if (_maxPerSquad < 0 && {_maxPerTeam < 0} && {_kitGroup isEqualTo ""}) exitWith {
    99
};

// Check kitGroup membership: player must belong to the required group
if (_kitGroup isNotEqualTo "") then {
    private _playerGroup = player getVariable [QEGVAR(Squad,kitGroup), ""];
    if (_playerGroup isNotEqualTo _kitGroup) exitWith {
        0
    };
};

private _remaining = 99;

// Count squad-level usage
if (_maxPerSquad >= 0) then {
    private _squadUnits = units group player;
    private _squadCount = 0;

    {
        private _unitKit = _x getVariable [QGVAR(currentKit), ""];
        if (_unitKit isEqualTo _kitClassName && {_x isNotEqualTo player}) then {
            _squadCount = _squadCount + 1;
        };
    } forEach _squadUnits;

    private _squadRemaining = _maxPerSquad - _squadCount;
    _remaining = _remaining min _squadRemaining;
};

// Count team-level usage (all squads on the same side)
if (_maxPerTeam >= 0) then {
    private _playerSide = side group player;
    private _teamCount = 0;

    {
        if (side _x isEqualTo _playerSide) then {
            {
                private _unitKit = _x getVariable [QGVAR(currentKit), ""];
                if (_unitKit isEqualTo _kitClassName && {_x isNotEqualTo player}) then {
                    _teamCount = _teamCount + 1;
                };
            } forEach units _x;
        };
    } forEach allGroups;

    private _teamRemaining = _maxPerTeam - _teamCount;
    _remaining = _remaining min _teamRemaining;
};

// Clamp to zero minimum
_remaining max 0
