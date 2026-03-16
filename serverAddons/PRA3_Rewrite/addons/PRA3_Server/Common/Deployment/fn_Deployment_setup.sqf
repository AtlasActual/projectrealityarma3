#include "script_component.hpp"
/*
    FUNC(setup)

    Initializes the Deployment subsystem on all machines. Establishes the
    primary storage structure for deploy points and declares the ordered
    list of field keys that constitute a valid deploy point record.

    Arguments: none
    Returns:   nothing
*/

// Primary registry — each key is a point ID string, each value is a HashMap
// holding the point's properties.
GVAR(pointStorage) = createHashMap;

// Ordered field keys every deploy point entry must contain.
GVAR(fieldKeys) = [
    "name",
    "type",
    "position",
    "availableFor",
    "spawnTickets",
    "icon",
    "mapIcon",
    "objects",
    "customData"
];

diag_log "[PRA3] [Deployment] Point storage created and field key list defined";
