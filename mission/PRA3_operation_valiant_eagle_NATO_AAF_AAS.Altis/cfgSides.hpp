class Sides {
    class West {
        name = "NATO";
        playerClass = "B_Soldier_F";
        flag = "a3\Data_f\cfgFactionClasses_BLU_ca.paa";
        mapIcon = "a3\ui_f\data\Map\Markers\NATO\b_installation.paa";
        color[] = {0, 0.3, 0.8, 1};
        squadRallyPointObjects[] = {{"Land_TentDome_F", {0,0,0}}};
        FOBBoxObject = "B_CargoNet_01_ammo_F";
        FOBComposition = "FOBNATO";

        #include "kitsWest.hpp"

        #include "cfgLogisticWest.hpp"
    };

    class GUER : WEST {
        name = "AAF";
        playerClass = "I_soldier_F";
        flag = "a3\Data_f\cfgFactionClasses_IND_ca.paa";
        mapIcon = "a3\ui_f\data\Map\Markers\NATO\n_installation.paa";
        color[] = {0, 0.5, 0, 1};
        squadRallyPointObjects[] = {{"Land_TentA_F", {0,0,0}}};
        FOBBoxObject = "I_CargoNet_01_ammo_F";
        FOBComposition = "FOBAAF";

        #include "kitsIndependent.hpp"

        #include "cfgLogisticIndependent.hpp"

    };
};
