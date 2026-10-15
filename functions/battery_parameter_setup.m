function cfg = battery_parameter_setup()
%BATTERY_PARAMETER_SETUP Centralized configuration for the thesis project.
% The chosen values are deliberately simple and defendable for an academic
% charging study of a 4S UAV LiPo battery pack.

cfg.project.title = "Design of a Battery Management System for UAV Multicell Battery Charging";
cfg.project.authorNote = "Simulation-only academic model for diploma thesis use.";

cfg.pack.numCells = 4;
cfg.pack.capacity_Ah = 5.0;
cfg.pack.capacity_As = cfg.pack.capacity_Ah * 3600;
cfg.pack.cellCapacity_Ah = [4.95; 5.02; 4.90; 4.98];
cfg.pack.cellCapacity_As = cfg.pack.cellCapacity_Ah * 3600;
cfg.pack.nominalCellVoltage_V = 3.7;
cfg.pack.maxCellVoltage_V = 4.20;
cfg.pack.minCellVoltage_V = 3.00;
cfg.pack.nominalPackVoltage_V = cfg.pack.numCells * cfg.pack.nominalCellVoltage_V;

% Initial mismatch is included so balancing activity is visible in plots.
cfg.init.soc = [0.42; 0.46; 0.40; 0.44];
cfg.init.temperature_C = [25; 25; 25; 25];

% Cell electrical model: OCV(SOC) in series with lumped internal resistance.
cfg.cell.internalResistance_Ohm = [0.018; 0.019; 0.017; 0.020];
cfg.cell.polarizationFactor = [0.985; 0.990; 0.980; 0.992];
cfg.cell.topOfChargeClampMargin_V = [0.002; 0.006; 0.004; 0.008];

% CC-CV charger settings. 0.5C is moderate and realistic for many UAV packs.
cfg.charge.ccCurrent_A = 2.5;
cfg.charge.cvTargetPackVoltage_V = cfg.pack.numCells * cfg.pack.maxCellVoltage_V;
cfg.charge.minTerminationCurrent_A = 0.25;
cfg.charge.currentRampGain_A_per_V = 2.2;
cfg.charge.terminationCurrent_A = 0.25;
cfg.charge.completionSoC = 0.992;
cfg.charge.cvCompletionVoltageTolerance_V = 0.06;
cfg.charge.cvTaperStartSoC = 0.94;

% Passive balancing uses resistors switched across high-voltage cells.
cfg.balance.enable = true;
cfg.balance.startVoltage_V = 4.00;
cfg.balance.hysteresis_V = 0.03;
cfg.balance.deltaTrigger_V = 0.008;
cfg.balance.resistor_Ohm = 18;
cfg.balance.maxBleedCurrent_A = cfg.pack.maxCellVoltage_V / cfg.balance.resistor_Ohm;
cfg.balance.targetResidualImbalance_V = 0.010;

% Simplified thermal model: first-order lumped thermal mass for each cell.
cfg.thermal.ambient_C = 25;
cfg.thermal.heatCapacity_J_per_C = 55;
cfg.thermal.convection_W_per_C = 0.28;
cfg.thermal.cellHeatCapacity_J_per_C = [54; 58; 52; 56];
cfg.thermal.cellConvection_W_per_C = [0.27; 0.29; 0.26; 0.30];
cfg.thermal.balanceHeatFraction = 1.0;

% Safety thresholds suitable for conservative demonstration.
cfg.safety.maxCellVoltage_V = 4.22;
cfg.safety.maxTemperature_C = 50;
cfg.safety.derateTemperature_C = 45;
cfg.safety.minCellVoltage_V = 2.90;

% SoC estimator settings.
cfg.soc.enableVoltageCorrection = true;
cfg.soc.voltageCorrectionGain = 0.015;
cfg.soc.blendCurrentThreshold_A = 0.35;

% Simulation settings.
cfg.sim.sampleTime_s = 1.0;
cfg.sim.stopTime_s = 14400;
cfg.sim.time_s = (0:cfg.sim.sampleTime_s:cfg.sim.stopTime_s).';

% Plotting and export options.
cfg.output.resultsFolder = "results";
cfg.output.saveFigures = false;
cfg.output.figureFormat = "png";

% Thesis assumptions documented inside the configuration for reuse.
cfg.assumptions = [
    "Cells are modeled as matched-capacity LiPo cells connected in series with small parameter mismatch."
    "The OCV-SOC relation is approximated by a smooth analytic equation rather than an experimental lookup table."
    "Internal resistance is constant for clarity, although real cells show temperature and SOC dependence."
    "Charging follows classical CC-CV logic: constant current until pack voltage reaches 16.8 V, then current tapers."
    "Passive balancing is activated only near full charge, where cell overvoltage risk is highest."
    "Thermal behavior is represented by a first-order lumped model suitable for control-level analysis."
    "A Coulomb-counting SoC estimator is used, with optional light voltage correction at low current."
    "The model focuses on charging behavior and supervisory BMS logic, not electrochemical cell dynamics."
    ];
end
