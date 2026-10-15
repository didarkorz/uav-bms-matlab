function scenarios = bms_get_scenarios(cfg)
%BMS_GET_SCENARIOS Scenario configuration for scripts 08-10.

scenarios = struct([]);

scenarios(1).name = "baseline_no_balancing";
scenarios(1).title = "Scenario 1 - No balancing";
scenarios(1).balance.enable = false;
scenarios(1).balance.startVoltage_V = inf;
scenarios(1).balance.threshold_V = inf;
scenarios(1).balance.resistor_Ohm = inf;
scenarios(1).balance.hysteresis_V = 0;
scenarios(1).ocvCorrection = false;
scenarios(1).adaptiveCurrentReduction = false;
scenarios(1).imbalanceDerateStart_V = inf;
scenarios(1).temperatureDerateStart_C = cfg.thermal.derateStart_C;
scenarios(1).cvEntryCellVoltage_V = cfg.charger.cvEntryCellVoltage_V;
scenarios(1).notes = "No balancing and no adaptive derating.";

scenarios(2).name = "basic_passive_balancing";
scenarios(2).title = "Scenario 2 - Basic passive balancing";
scenarios(2).balance.enable = true;
scenarios(2).balance.startVoltage_V = cfg.balance.basic.startVoltage_V;
scenarios(2).balance.threshold_V = cfg.balance.basic.threshold_V;
scenarios(2).balance.resistor_Ohm = cfg.balance.basic.resistor_Ohm;
scenarios(2).balance.hysteresis_V = cfg.balance.basic.hysteresis_V;
scenarios(2).ocvCorrection = false;
scenarios(2).adaptiveCurrentReduction = false;
scenarios(2).imbalanceDerateStart_V = 0.040;
scenarios(2).temperatureDerateStart_C = cfg.thermal.derateStart_C;
scenarios(2).cvEntryCellVoltage_V = cfg.charger.cvEntryCellVoltage_V;
scenarios(2).notes = "Balancing starts late and current is not reduced when imbalance grows.";

scenarios(3).name = "improved_bms";
scenarios(3).title = "Scenario 3 - Improved BMS";
scenarios(3).balance.enable = true;
scenarios(3).balance.startVoltage_V = cfg.balance.improved.startVoltage_V;
scenarios(3).balance.threshold_V = cfg.balance.improved.threshold_V;
scenarios(3).balance.resistor_Ohm = cfg.balance.improved.resistor_Ohm;
scenarios(3).balance.hysteresis_V = cfg.balance.improved.hysteresis_V;
scenarios(3).ocvCorrection = true;
scenarios(3).adaptiveCurrentReduction = true;
scenarios(3).imbalanceDerateStart_V = 0.020;
scenarios(3).temperatureDerateStart_C = 38;
scenarios(3).cvEntryCellVoltage_V = 4.15;
scenarios(3).notes = "Earlier balancing, imbalance-based derating, thermal derating, and clean current-cutoff termination.";
end
