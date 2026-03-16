#include "macros.hpp"

class CfgPatches {
    class PRA3_Server {
        units[] = {};
        weapons[] = {};
        requiredVersion = 2.14;
        author = "Project Reality ArmA 3 Rewrite Team";
        authors[] = {"Project Reality ArmA 3 Rewrite Team"};
        authorUrl = "";
        version = VERSION;
        versionStr = QUOTE(VERSION);
        versionAr[] = {VERSION_AR};
        requiredAddons[] = {"A3_Functions_F"};
    };
};

#include "CfgFunctions.hpp"
#include "CfgLocalizations.hpp"
#include "FOB\CfgCompositions.hpp"

class PREFIX {
    class DOUBLE(PREFIX,Extension) {
        version = "1.0";
    };
};
