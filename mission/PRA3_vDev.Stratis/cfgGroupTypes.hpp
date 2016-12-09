class GroupTypes {
    class Rifle {
        displayName = "Rifle";
        groupSize = 9;
        requiredGroups = 0;
        requiredPlayers = 1;
        mapIcon = "\A3\ui_f\data\map\markers\nato\b_inf.paa";
    };
    class Weapon: Rifle {
        displayName = "Heavy";
        requiredGroups = 0;
        requiredPlayers = 1;
        mapIcon = "\A3\ui_f\data\map\markers\nato\b_inf.paa";
    };
    class Recon {
        displayName = "Recon";
        groupSize = 4;
        requiredGroups = 0;
        requiredPlayers = 1;
        mapIcon = "\A3\ui_f\data\map\markers\nato\b_recon.paa";
    };
    class Vehicle {
        displayName = "Crew";
        groupSize = 4;
        requiredGroups = 0;
        requiredPlayers = 1;
        mapIcon = "\A3\ui_f\data\map\markers\nato\b_armor.paa";
    };
    class Helicopter: Vehicle {
        displayName = "Heli";
        requiredPlayers = 15;
        mapIcon = "\A3\ui_f\data\map\markers\nato\b_air.paa";
    };
    class Mortar {
        displayName = "Mortar";
        groupSize = 3;
        requiredGroups = 0;
        requiredPlayers = 1;
        mapIcon = "\A3\ui_f\data\map\markers\nato\b_mortar.paa";
    };
    class Logistic {
        displayName = "Logistic";
        groupSize = 4;
        requiredGroups = 0;
        requiredPlayers = 1;
        mapIcon = "\A3\ui_f\data\map\markers\nato\b_support.paa";
    };
};
class KitGroups {
    class Unlimited {
        requiredGroupMembersPerKit = 1;
    };
    class Limited {
        requiredGroupMembersPerKit = 1;
    };
    class Specialized {
        requiredGroupMembersPerKit = 1;
    };
};
