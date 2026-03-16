class CfgFunctions {
    class PREFIX {
        tag = QUOTE(PREFIX);

        // --- Framework ---
        class Framework {
            file = "\pr\PRA3\addons\PRA3_Server\Framework";
            class fw_eventBus {};
            class fw_perFrame {};
            class fw_stateMachine {};
            class fw_mutex {};
            class fw_utilities {};
            class fw_localization {};
            class fw_bootstrap {};
        };

        // --- Common ---
        class Common {
            file = "\pr\PRA3\addons\PRA3_Server\Common";
            class Common_init { preInit = 1; };
            class Common_isAlive {};
            class Common_nearestLocation {};
        };

        // --- Common/Deployment ---
        class Deployment {
            file = "\pr\PRA3\addons\PRA3_Server\Common\Deployment";
            class Deployment_setup {};
            class Deployment_serverSetup {};
            class Deployment_clientSetup {};
            class Deployment_addPoint {};
            class Deployment_removePoint {};
            class Deployment_getAvailable {};
            class Deployment_getForSide {};
            class Deployment_getData {};
            class Deployment_setData {};
            class Deployment_getCustom {};
            class Deployment_setCustom {};
            class Deployment_consumeSpawn {};
            class Deployment_isValid {};
        };

        // --- Common/EntityVariables ---
        class EntityVariables {
            file = "\pr\PRA3\addons\PRA3_Server\Common\EntityVariables";
            class EntityVariables_apply {};
        };

        // --- Common/Respawn ---
        class Respawn {
            file = "\pr\PRA3\addons\PRA3_Server\Common\Respawn";
            class Respawn_execute {};
            class Respawn_changeSide {};
        };

        // --- Common/Notification ---
        class Notification {
            file = "\pr\PRA3\addons\PRA3_Server\Common\Notification";
            class Notification_clientSetup {};
            class Notification_show {};
            class Notification_processQueue {};
        };

        // --- Common/PerformanceInfo ---
        class PerformanceInfo {
            file = "\pr\PRA3\addons\PRA3_Server\Common\PerformanceInfo";
            class PerformanceInfo_clientSetup {};
            class PerformanceInfo_serverSetup {};
        };

        // --- CompassUI ---
        class CompassUI {
            file = "\pr\PRA3\addons\PRA3_Server\CompassUI";
            class CompassUI_clientSetup {};
            class CompassUI_addMarker {};
            class CompassUI_removeMarker {};
        };

        // --- Sector ---
        class Sector {
            file = "\pr\PRA3\addons\PRA3_Server\Sector";
            class Sector_init {};
            class Sector_clientSetup {};
            class Sector_serverSetup {};
            class Sector_createLogic {};
            class Sector_draw {};
            class Sector_get {};
            class Sector_canCapture {};
            class Sector_captureLoop {};
            class Sector_captureHUD {};
            class Sector_refreshDependencies {};
        };

        // --- Tickets ---
        class Tickets {
            file = "\pr\PRA3\addons\PRA3_Server\Tickets";
            class Tickets_init {};
            class Tickets_modify {};
        };

        // --- Squad ---
        class Squad {
            file = "\pr\PRA3\addons\PRA3_Server\Squad";
            class Squad_clientSetup {};
            class Squad_create {};
            class Squad_join {};
            class Squad_leave {};
            class Squad_kick {};
            class Squad_promote {};
            class Squad_nextId {};
            class Squad_typeAllowed {};
            class Squad_canChangeSide {};
            class Squad_changeSide {};
        };

        // --- Kit ---
        class Kit {
            file = "\pr\PRA3\addons\PRA3_Server\Kit";
            class Kit_clientSetup {};
            class Kit_listAll {};
            class Kit_details {};
            class Kit_availability {};
            class Kit_equip {};
        };

        // --- Revive ---
        class Revive {
            file = "\pr\PRA3\addons\PRA3_Server\Revive";
            class Revive_clientSetup {};
            class Revive_handleDamage {};
            class Revive_knockOut {};
            class Revive_bleedLoop {};
            class Revive_bloodScreen {};
            class Revive_healAction {};
            class Revive_reviveAction {};
            class Revive_dragAction {};
            class Revive_forceRespawn {};
            class Revive_unloadAction {};
        };

        // --- FOB ---
        class FOB {
            file = "\pr\PRA3\addons\PRA3_Server\FOB";
            class FOB_clientSetup {};
            class FOB_serverSetup {};
            class FOB_place {};
            class FOB_canPlace {};
            class FOB_buildAction {};
            class FOB_destroyAction {};
            class FOB_defuseAction {};
            class FOB_dismantleAction {};
        };

        // --- Rally ---
        class Rally {
            file = "\pr\PRA3\addons\PRA3_Server\Rally";
            class Rally_clientSetup {};
            class Rally_serverSetup {};
            class Rally_place {};
            class Rally_canPlace {};
            class Rally_destroy {};
        };

        // --- RespawnUI ---
        class RespawnUI {
            file = "\pr\PRA3\addons\PRA3_Server\RespawnUI";
            class RespawnUI_clientSetup {};
            class RespawnUI_deploymentSetup {};
            class RespawnUI_roleSetup {};
            class RespawnUI_squadSetup {};
            class RespawnUI_cameraSetup {};
            class RespawnUI_escapeHandler {};
            class RespawnUI_populateList {};
            class RespawnUI_animateControl {};
        };

        // --- Logistic ---
        class Logistic {
            file = "\pr\PRA3\addons\PRA3_Server\Logistic";
            class Logistic_clientSetup {};
            class Logistic_serverSetup {};
            class Logistic_actionsSetup {};
            class Logistic_cargoUI {};
            class Logistic_grab {};
            class Logistic_release {};
            class Logistic_calcWeight {};
            class Logistic_createCrate {};
        };

        // --- Nametags ---
        class Nametags {
            file = "\pr\PRA3\addons\PRA3_Server\Nametags";
            class Nametags_clientSetup {};
        };

        // --- UnitTracker ---
        class UnitTracker {
            file = "\pr\PRA3\addons\PRA3_Server\UnitTracker";
            class UnitTracker_clientSetup {};
            class UnitTracker_drawUnit {};
            class UnitTracker_drawGroup {};
            class UnitTracker_drawVehicle {};
        };

        // --- SquadRespawn ---
        class SquadRespawn {
            file = "\pr\PRA3\addons\PRA3_Server\SquadRespawn";
            class SquadRespawn_clientSetup {};
        };

        // --- VehicleRespawn ---
        class VehicleRespawn {
            file = "\pr\PRA3\addons\PRA3_Server\VehicleRespawn";
            class VehicleRespawn_clientSetup {};
            class VehicleRespawn_serverSetup {};
            class VehicleRespawn_doRespawn {};
        };
    };
};
