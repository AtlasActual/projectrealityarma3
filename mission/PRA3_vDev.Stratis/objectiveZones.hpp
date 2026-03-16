
// base config
class zone {
    dependency[] = {};
    ticketValue = 30;
    captureTime[] = {30,60};
    minUnits = 1;
    isLastSector = "";
    firstCaptureTime[] = {5,15};
};

class ObjectiveZones {

    class base_west : zone {
        designator = "HQ";
    };

    class base_east : zone {
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
                dependency[] = {"sector_2","base_east"};
                designator = "D";
            };
        };

        class path_1 {
            class sector_5 : zone {
                dependency[] = {"base_west","sector_9"};
                designator = "A";
            };

            class sector_9 : zone {
                dependency[] = {"sector_5","sector_6"};
                designator = "B";
            };

            class sector_6 : zone {
                dependency[] = {"sector_9","sector_3"};
                designator = "C";
            };

            class sector_3 : zone {
                dependency[] = {"sector_6","base_east"};
                designator = "D";
            };
        };

        class path_3 {
            class sector_4 : zone {
                dependency[] = {"base_west","sector_8"};
                designator = "A";
            };

            class sector_8 : zone {
                dependency[] = {"sector_4","sector_13"};
                designator = "B";
            };

            class sector_13 : zone {
                dependency[] = {"sector_8","sector_10"};
                designator = "C";
            };

            class sector_10 : zone {
                dependency[] = {"sector_13","base_east"};
                designator = "D";
            };
        };

        class path_4 {
            class sector_12 : zone {
                dependency[] = {"base_west","sector_11"};
                designator = "A";
            };

            class sector_11 : zone {
                dependency[] = {"sector_12","sector_2"};
                designator = "B";
            };

            class sector_2 : zone {
                dependency[] = {"sector_11","sector_7"};
                designator = "C";
            };

            class sector_7 : zone {
                dependency[] = {"sector_2","base_east"};
                designator = "D";
            };
        };

        class path_5 {
            class sector_4 : zone {
                dependency[] = {"base_west","sector_9"};
                designator = "A";
            };

            class sector_9 : zone {
                dependency[] = {"sector_4","sector_6"};
                designator = "B";
            };

            class sector_6 : zone {
                dependency[] = {"sector_9","sector_3"};
                designator = "C";
            };

            class sector_3 : zone {
                dependency[] = {"sector_6","base_east"};
                designator = "D";
            };
        };

        class path_6 {
            class sector_0 : zone {
                dependency[] = {"base_west","sector_9"};
                designator = "A";
            };

            class sector_9 : zone {
                dependency[] = {"sector_0","sector_2"};
                designator = "B";
            };

            class sector_2 : zone {
                dependency[] = {"sector_9","sector_3"};
                designator = "C";
            };

            class sector_3 : zone {
                dependency[] = {"sector_2","base_east"};
                designator = "D";
            };
        };

        class path_7 {
            class sector_4 : zone {
                dependency[] = {"base_west","sector_9"};
                designator = "A";
            };

            class sector_9 : zone {
                dependency[] = {"sector_4","sector_3"};
                designator = "B";
            };

            class sector_3 : zone {
                dependency[] = {"sector_9","sector_10"};
                designator = "C";
            };

            class sector_10 : zone {
                dependency[] = {"sector_3","base_east"};
                designator = "D";
            };
        };
    };
};
