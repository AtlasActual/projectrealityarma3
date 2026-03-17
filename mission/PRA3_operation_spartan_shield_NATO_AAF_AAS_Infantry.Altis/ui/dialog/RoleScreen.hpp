class PRA3_UI_RoleScreen {
    idd = 3000;
    onLoad = "['PRA3_UI_RoleScreen_onLoad', _this] call PRA3_fw_fireEvent;";
    onUnload = "['PRA3_UI_RoleScreen_onUnload', []] call PRA3_fw_fireEvent;";

    class Controls {
        class RoleManagement : PRA3_UI_RoleManagement {};
    };
};
