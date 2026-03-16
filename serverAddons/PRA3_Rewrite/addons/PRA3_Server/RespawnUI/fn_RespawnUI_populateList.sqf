#include "script_component.hpp"
/*
    FUNC(populateList)

    Description:
        Utility function that clears and repopulates a ListNBox control
        with the provided data array. Attempts to preserve the previous
        selection by matching stored data values. If the previous selection
        is no longer present, defaults to the first row.

    Parameters:
        0: _control       - CONTROL - the ListNBox control to populate
        1: _allData        - ARRAY   - entries, each formatted as:
                             [[text1, text2, ...], dataValue, iconPath]
        2: _preferredValue - ANY     - (optional) data value to select
                             if present; otherwise keeps current selection

    Returns:
        ANY - the data value of the resulting selected row, or nil if empty
*/

params ["_control", "_allData", ["_preferredValue", nil]];

// Determine which data value was selected before the refresh
private _prevSelValue = nil;

if (!isNil "_preferredValue") then {
    _prevSelValue = _preferredValue;
} else {
    private _prevRow = lnbCurSelRow _control;
    if (_prevRow >= 0) then {
        _prevSelValue = _control lnbData [_prevRow, 0];
    };
};

// Track which data values are added for selection restoration
private _insertedValues = [];

// Clear existing content
lnbClear _control;

// Insert each entry
{
    _x params ["_columns", "_data", ["_icon", ""]];

    private _row = _control lnbAddRow _columns;

    // Store the data value as a string in column 0
    _control lnbSetData [[_row, 0], str _data];
    _insertedValues pushBack (str _data);

    // Set the row icon if provided
    if (_icon isNotEqualTo "") then {
        _control lnbSetPicture [[_row, 0], _icon];
    };

    // Restore selection if this row matches the previous value
    if (!isNil "_prevSelValue" && {(str _data) isEqualTo (str _prevSelValue)}) then {
        _control lnbSetCurSelRow _row;
    };
} forEach _allData;

// Handle edge cases for selection
private _rowCount = lnbSize _control select 0;

if (_rowCount isEqualTo 0) then {
    // Empty list: clear selection
    _control lnbSetCurSelRow -1;
    _prevSelValue = nil;
} else {
    // If previous selection was not restored, select the first row
    if (lnbCurSelRow _control < 0) then {
        _control lnbSetCurSelRow 0;
        _prevSelValue = _control lnbData [0, 0];
    } else {
        _prevSelValue = _control lnbData [lnbCurSelRow _control, 0];
    };
};

// Return the currently selected data value
_prevSelValue
