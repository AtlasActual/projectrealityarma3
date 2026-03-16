
// base config
class zone {
    dependency[] = {};
    ticketValue = 30;
    captureTime[] = {60,90};
    minUnits = 2;
    isLastSector = "";
    firstCaptureTime[] = {15,30};
};

class ObjectiveZones {

    class base_west : zone {
        designator = "HQ";
    };

    class base_guer : zone {
        designator = "HQ";
    };

    class ZoneRoutes {
        class path_0 {
            class sector_0 : zone {
                dependency[] = {"base_west","sector_1"};
                designator = "A";
            };

            class sector_1 : zone {
                dependency[] = {"sector_0","sector_2"};
                designator = "B";
            };

            class sector_2 : zone {
                dependency[] = {"sector_1","sector_3"};
                designator = "C";
            };

            class sector_3 : zone {
                dependency[] = {"sector_2","base_guer"};
                designator = "D";
            };

        };

        class path_1 {
            class sector_0 : zone {
                dependency[] = {"base_west","sector_1"};
                designator = "A";
            };

            class sector_1 : zone {
                dependency[] = {"sector_0","sector_4"};
                designator = "B";
            };

            class sector_4 : zone {
                dependency[] = {"sector_1","sector_5"};
                designator = "C";
            };

            class sector_5 : zone {
                dependency[] = {"sector_4","base_guer"};
                designator = "D";
            };

        };

    };
};
