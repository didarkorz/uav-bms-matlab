function cfg = bms_default_cfg(projectRoot)
%BMS_DEFAULT_CFG Central configuration for the diploma BMS workflow.

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(mfilename("fullpath")));
end

cfg.project.title = "Design of a Battery Management System (BMS) for UAV Multicell Battery Charging";
cfg.project.shortTitle = "4S UAV LiPo BMS";
cfg.project.created_on = char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));

cfg.paths.projectRoot = projectRoot;
cfg.paths.datasetsRoot = fullfile(projectRoot, "datasets");
cfg.paths.scripts = fullfile(projectRoot, "scripts");
cfg.paths.functions = fullfile(projectRoot, "functions");
cfg.paths.simulink = fullfile(projectRoot, "simulink");
cfg.paths.results = fullfile(projectRoot, "results");
cfg.paths.reports = fullfile(projectRoot, "reports");
cfg.paths.processed = fullfile(projectRoot, "data", "processed");
cfg.paths.raw.nasa = fullfile(projectRoot, "data", "raw", "nasa");
cfg.paths.raw.oxford = fullfile(projectRoot, "data", "raw", "oxford");
cfg.paths.raw.calce = fullfile(projectRoot, "data", "raw", "calce");
cfg.paths.raw.stanford = fullfile(projectRoot, "data", "raw", "stanford");

cfg.paths.search.nasa = {
    cfg.paths.raw.nasa
    fullfile(cfg.paths.datasetsRoot, "NASA dataset")
    };
cfg.paths.search.oxford = {
    cfg.paths.raw.oxford
    fullfile(cfg.paths.datasetsRoot, "oxford dataset")
    };
cfg.paths.search.calce = {
    cfg.paths.raw.calce
    fullfile(cfg.paths.datasetsRoot, "calce dataset")
    };
cfg.paths.search.stanford = {
    cfg.paths.raw.stanford
    fullfile(cfg.paths.datasetsRoot, "stanford dataset")
    };
cfg.paths.search.uav = {
    fullfile(projectRoot, "data", "raw", "uav")
    fullfile(cfg.paths.datasetsRoot, "uav dataset")
    };

cfg.files.cfg = fullfile(cfg.paths.results, "cfg.mat");
cfg.files.nasa = fullfile(cfg.paths.processed, "nasa_standardized.mat");
cfg.files.oxford = fullfile(cfg.paths.processed, "oxford_standardized.mat");
cfg.files.calce = fullfile(cfg.paths.processed, "calce_standardized.mat");
cfg.files.stanford = fullfile(cfg.paths.processed, "stanford_standardized.mat");
cfg.files.ocvLookup = fullfile(cfg.paths.results, "ocv_soc_lookup.mat");
cfg.files.cellParameters = fullfile(cfg.paths.results, "identified_cell_parameters.mat");
cfg.files.packModel = fullfile(cfg.paths.results, "pack_model_4s.mat");
cfg.files.scenarioBundle = fullfile(cfg.paths.results, "scenario_results_bundle.mat");
cfg.files.validation = fullfile(cfg.paths.results, "model_validation_metrics.csv");
cfg.files.parameterAudit = fullfile(cfg.paths.results, "parameter_audit.csv");
cfg.files.diplomaDraft = fullfile(cfg.paths.reports, "diploma_practical_section_draft.md");

cfg.datasets.sources = {
    "NASA PCoE Li-ion Battery Aging Dataset"
    "Oxford Battery Degradation Dataset 1"
    "CALCE Battery Dataset"
    "Stanford/MATR Battery Dataset"
    "Di Nisio et al. UAV LiPo 4S reference"
    };

cfg.processing.standardColumns = [
    "time_s", "voltage_V", "current_A", "temp_C", ...
    "capacity_Ah", "dataset_id", "cell_id", "cycle_id"
    ];
cfg.processing.ocvSocGrid = (0:0.01:1).';
cfg.processing.defaultOcvTemperature_C = 25;
cfg.processing.temperatureTolerance_C = 5;
cfg.processing.maxRowsPerFile = 5000;
cfg.processing.maxRowsPerRecord = 250;
cfg.processing.maxValidationRows = 3000;

cfg.pack.numCells = 4;
cfg.pack.nominalCellCapacity_Ah = 5.0;
cfg.pack.nominalPackCapacity_Ah = cfg.pack.nominalCellCapacity_Ah;
cfg.pack.nominalCellVoltage_V = 3.7;
cfg.pack.maxCellVoltage_V = 4.20;
cfg.pack.minCellVoltage_V = 3.00;
cfg.pack.maxPackVoltage_V = cfg.pack.numCells * cfg.pack.maxCellVoltage_V;
cfg.pack.nominalPackVoltage_V = cfg.pack.numCells * cfg.pack.nominalCellVoltage_V;

cfg.cells.capacity_Ah = [5.00, 4.92, 5.05, 4.88];
cfg.cells.R0_Ohm = [0.018, 0.022, 0.017, 0.024];
cfg.cells.initialSoC = [0.42, 0.46, 0.40, 0.44];
cfg.cells.initialTemp_C = [26.0, 27.0, 25.5, 26.5];
cfg.cells.R1_Ohm = [0.007, 0.008, 0.0065, 0.0085];
cfg.cells.C1_F = [2400, 2200, 2600, 2100];
cfg.cells.eta_charge = [0.996, 0.995, 0.997, 0.994];
cfg.cells.Cth_J_per_C = [175, 168, 180, 165];
cfg.cells.hA_W_per_C = [0.78, 0.72, 0.81, 0.69];

cfg.charger.ccCurrent_A = 2.5;
cfg.charger.currentCutoff_A = 0.25;
cfg.charger.cvTargetPackVoltage_V = cfg.pack.maxPackVoltage_V;
cfg.charger.cvEntryCellVoltage_V = 4.18;
cfg.charger.currentKp_A_per_V = 3.0;
cfg.charger.minCompletionSoC = 0.965;

cfg.balance.maxBleedCurrent_A = 0.25;
cfg.balance.basic.startVoltage_V = 4.10;
cfg.balance.basic.threshold_V = 0.015;
cfg.balance.basic.resistor_Ohm = 33;
cfg.balance.basic.hysteresis_V = 0.005;
cfg.balance.improved.startVoltage_V = 4.00;
cfg.balance.improved.threshold_V = 0.010;
cfg.balance.improved.resistor_Ohm = 18;
cfg.balance.improved.hysteresis_V = 0.005;

cfg.thermal.ambient_C = 25;
cfg.thermal.maxTemperature_C = 45;
cfg.thermal.protectionTemperature_C = 48;
cfg.thermal.derateStart_C = 40;

cfg.sim.dt_s = 1.0;
cfg.sim.stopTime_s = 18000;
cfg.sim.time_s = (0:cfg.sim.dt_s:cfg.sim.stopTime_s).';

cfg.targets.finalVoltageImbalance_V = 0.020;
cfg.targets.finalSoCSpread_pct = 2.0;
cfg.targets.maxTemperature_C = 45;
cfg.targets.maxCellVoltage_V = 4.20;
cfg.targets.endByCutoff = true;

cfg.socCorrection.enable = true;
cfg.socCorrection.blendGain = 0.08;
cfg.socCorrection.currentThreshold_A = 0.40;

cfg.reporting.figureFormat = "png";
cfg.reporting.saveFigures = true;
cfg.reporting.statusPassName = "PASS";
cfg.reporting.statusWarnName = "WARNING";
cfg.reporting.statusFailName = "FAIL";
cfg.reporting.mirrorReportToResults = true;
end
