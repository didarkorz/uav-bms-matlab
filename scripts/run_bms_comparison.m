%% run_bms_comparison.m
% Three-scenario engineering study for the UAV BMS diploma project:
% 1. No balancing
% 2. Basic passive balancing
% 3. Optimized passive balancing

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
run(fullfile(projectRoot, "config", "init_bms_project.m"));

scenario(1).name = "Scenario 1 - No Balancing";
scenario(1).cfg = cfg;
scenario(1).cfg.balance.enable = false;
scenario(1).cfg.sim.stopTime_s = 10800;
scenario(1).cfg.sim.time_s = (0:scenario(1).cfg.sim.sampleTime_s:scenario(1).cfg.sim.stopTime_s).';
scenario(1).notes = "Baseline charging study with realistic cell mismatch and passive balancing disabled.";

scenario(2).name = "Scenario 2 - Basic Passive Balancing";
scenario(2).cfg = cfg;
scenario(2).cfg.balance.enable = true;
scenario(2).cfg.balance.startVoltage_V = 4.08;
scenario(2).cfg.balance.deltaTrigger_V = 0.010;
scenario(2).cfg.balance.resistor_Ohm = 27;
scenario(2).cfg.balance.maxBleedCurrent_A = scenario(2).cfg.pack.maxCellVoltage_V / scenario(2).cfg.balance.resistor_Ohm;
scenario(2).cfg.sim.stopTime_s = 10800;
scenario(2).cfg.sim.time_s = (0:scenario(2).cfg.sim.sampleTime_s:scenario(2).cfg.sim.stopTime_s).';
scenario(2).notes = "Conservative passive balancing design using a later threshold and weaker bleed branch.";

scenario(3).name = "Scenario 3 - Optimized Passive Balancing";
scenario(3).cfg = cfg;
scenario(3).cfg.balance.enable = true;
scenario(3).cfg.balance.startVoltage_V = 4.00;
scenario(3).cfg.balance.deltaTrigger_V = 0.008;
scenario(3).cfg.balance.resistor_Ohm = 18;
scenario(3).cfg.balance.maxBleedCurrent_A = scenario(3).cfg.pack.maxCellVoltage_V / scenario(3).cfg.balance.resistor_Ohm;
scenario(3).cfg.charge.currentRampGain_A_per_V = 2.2;
scenario(3).cfg.sim.stopTime_s = 14400;
scenario(3).cfg.sim.time_s = (0:scenario(3).cfg.sim.sampleTime_s:scenario(3).cfg.sim.stopTime_s).';
scenario(3).notes = "Tuned passive balancing design targeting low final imbalance, low SoC spread, and normal CV cutoff termination.";

studies = struct("name", {}, "results", {}, "report", {}, "cfg", {});

for idx = 1:numel(scenario)
    disp(" ");
    disp("============================================================");
    disp(upper(scenario(idx).name));
    disp("============================================================");

    results = simulate_bms_charge(scenario(idx).cfg);

    reportOptions.projectRoot = projectRoot;
    reportOptions.outputFolder = fullfile(projectRoot, "results", matlab.lang.makeValidName(scenario(idx).name));
    reportOptions.modelName = "MATLAB Discrete BMS Charging Model";
    reportOptions.simulationType = scenario(idx).name;
    reportOptions.solver = "Fixed-step discrete script model";
    reportOptions.sampleTime_s = scenario(idx).cfg.sim.sampleTime_s;
    reportOptions.notes = scenario(idx).notes;

    report = generate_simulation_report(results, scenario(idx).cfg, reportOptions);

    disp("Engineering interpretation:");
    disp(report.metrics.performance.engineeringInterpretation);

    studies(idx).name = scenario(idx).name;
    studies(idx).results = results;
    studies(idx).report = report;
    studies(idx).cfg = scenario(idx).cfg;
end

plot_scenario_comparison(studies, cfg, fullfile(projectRoot, "results", "scenario_comparison"));

scenarioNames = string({studies.name}).';
initialImbalance_V = arrayfun(@(s) s.report.metrics.balancing.initialImbalance_V, studies).';
finalImbalance_V = arrayfun(@(s) s.report.metrics.balancing.finalImbalance_V, studies).';
finalSoCSpread_percent = arrayfun(@(s) s.report.metrics.performance.finalSoCSpread_percent, studies).';
ccDuration_s = arrayfun(@(s) s.report.metrics.charging.ccDuration_s, studies).';
cvDuration_s = arrayfun(@(s) s.report.metrics.charging.cvDuration_s, studies).';
totalChargingTime_s = arrayfun(@(s) s.report.metrics.charging.totalChargingTime_s, studies).';
finalCurrent_A = arrayfun(@(s) s.report.metrics.charging.finalCurrent_A, studies).';
maxTemperature_C = arrayfun(@(s) max(s.report.metrics.temperature.maxTemperaturePerCell_C), studies).';
terminationReason = cell(numel(studies), 1);
resultLabel = cell(numel(studies), 1);

for idx = 1:numel(studies)
    terminationReason{idx} = char(string(studies(idx).report.metrics.charging.terminationReason));
    resultLabel{idx} = char(string(studies(idx).report.metrics.performance.overallResult));
end

summaryTable = table( ...
    scenarioNames, ...
    initialImbalance_V, ...
    finalImbalance_V, ...
    finalSoCSpread_percent, ...
    ccDuration_s, ...
    cvDuration_s, ...
    totalChargingTime_s, ...
    finalCurrent_A, ...
    maxTemperature_C, ...
    terminationReason, ...
    resultLabel, ...
    'VariableNames', { ...
        'Scenario', ...
        'InitialImbalance_V', ...
        'FinalImbalance_V', ...
        'FinalSoCSpread_percent', ...
        'CC_Duration_s', ...
        'CV_Duration_s', ...
        'TotalChargingTime_s', ...
        'FinalCurrent_A', ...
        'MaxTemperature_C', ...
        'TerminationReason', ...
        'Result'});

disp(" ");
disp("============================================================");
disp("FINAL COMPARISON TABLE");
disp("============================================================");
disp(summaryTable);

comparisonOutputFolder = fullfile(projectRoot, "results", "scenario_comparison");
if ~isfolder(comparisonOutputFolder)
    mkdir(comparisonOutputFolder);
end

writetable(summaryTable, fullfile(comparisonOutputFolder, "scenario_comparison_summary.csv"));
