class PRA3_UI_SquadScreen {
    idd = 2000;
    onLoad = "['PRA3_UI_SquadScreen_onLoad', _this] call PRA3_fw_fireEvent;";
    onUnload = "['PRA3_UI_SquadScreen_onUnload', []] call PRA3_fw_fireEvent;";

    class Controls {
        class SquadManagement : PRA3_UI_SquadManagement {
            y = PY(5) + safeZoneY;
        };
    };
};
