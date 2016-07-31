#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: BadGuy

    Description:
    Client Init of 3d Icons

    Parameter(s):
    None

    Returns:
    None
*/

//Namespace for Layer
GVAR(3dGraphicsNamespace) = call FUNC(createNamespace);

GVAR(3dGraphicsCache) = [];
GVAR(3dGraphicsCacheBuildFlag) = 0; // Should be incremented for each rebuild
GVAR(3dGraphicsCacheVersion) = 0;

// Use the missionStarted EH to prevent unnecessary executions.
["missionStarted", {
    // The draw3D event triggers on each frame if the client window has focus.
    addMissionEventHandler ["Draw3D", FUNC(draw3dGraphics)];
}] call CFUNC(addEventHandler);
