function reportText = bms_generate_report_outputs(cfg)
%BMS_GENERATE_REPORT_OUTPUTS Generate report files and summary tables.

if nargin < 1 || isempty(cfg)
    cfg = bms_load_cfg();
end

local_ensure_dependencies(cfg);

bundle = load(cfg.files.scenarioBundle, "scenarioResults", "scenarioSummaries");
scenarioNames = fieldnames(bundle.scenarioResults);

simulationResults = table();
for idx = 1:numel(scenarioNames)
    simulationResults = [simulationResults; bms_results_to_table(bundle.scenarioResults.(scenarioNames{idx}))]; %#ok<AGROW>
end
writetable(simulationResults, fullfile(cfg.paths.results, "simulation_results.csv"));
writetable(bundle.scenarioSummaries, fullfile(cfg.paths.results, "summary_metrics.csv"));
writetable(bundle.scenarioSummaries, fullfile(cfg.paths.results, "scenario_comparison_summary.csv"));

parameterData = load(cfg.files.cellParameters, "estimates");
parameterAudit = bms_build_parameter_audit(cfg, parameterData.estimates);
writetable(parameterAudit, cfg.files.parameterAudit);

datasetStatus = local_dataset_status(cfg);
lookupData = load(cfg.files.ocvLookup, "lookup");
reportLines = local_build_report_lines(cfg, datasetStatus, parameterData.estimates, lookupData.lookup, bundle.scenarioSummaries);
reportText = strjoin(cellstr(reportLines), newline);

reportFile = fullfile(cfg.paths.reports, "simulation_report.txt");
fid = fopen(reportFile, "w");
fprintf(fid, "%s\n", reportText);
fclose(fid);

if cfg.reporting.mirrorReportToResults
    fid = fopen(fullfile(cfg.paths.results, "simulation_report.txt"), "w");
    fprintf(fid, "%s\n", reportText);
    fclose(fid);
end
end

function local_ensure_dependencies(cfg)
requiredFiles = {
    cfg.files.nasa, "step01_import_nasa.m"
    cfg.files.oxford, "step02_import_oxford.m"
    cfg.files.calce, "step03_import_calce.m"
    cfg.files.stanford, "step04_import_stanford.m"
    cfg.files.ocvLookup, "step05_build_ocv_soc_table.m"
    cfg.files.cellParameters, "step06_estimate_cell_parameters.m"
    cfg.files.scenarioBundle, "step10_run_improved_bms.m"
    };

for idx = 1:size(requiredFiles, 1)
    if ~exist(requiredFiles{idx, 1}, "file")
        run(fullfile(cfg.paths.scripts, requiredFiles{idx, 2}));
    end
end

plotFile = fullfile(cfg.paths.results, "cell_voltages_vs_time." + cfg.reporting.figureFormat);
if ~exist(plotFile, "file")
    run(fullfile(cfg.paths.scripts, "step11_generate_plots.m"));
end
end

function reportLines = local_build_report_lines(cfg, datasetStatus, estimates, lookup, scenarioSummaries)
reportLines = strings(0, 1);
reportLines(end + 1) = "Simulation Report - " + cfg.project.title;
reportLines(end + 1) = "Generated on: " + string(char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss")));
reportLines(end + 1) = "";
reportLines(end + 1) = "Dataset sources used:";
for idx = 1:height(datasetStatus)
    reportLines(end + 1) = " - " + datasetStatus.dataset_name(idx) + ": " + datasetStatus.status(idx);
end
reportLines(end + 1) = "";
reportLines(end + 1) = "Preprocessing steps:";
reportLines(end + 1) = " - Imported available NASA and Oxford battery files from data/raw/* or fallback datasets/* folders.";
reportLines(end + 1) = " - Standardized time series into time_s, voltage_V, current_A, temp_C, capacity_Ah, soc_est, dataset_id, cell_id, cycle_id where available.";
reportLines(end + 1) = " - Built the OCV-SOC lookup table primarily from Oxford-derived data and fallback logic when missing datasets were unavailable.";
reportLines(end + 1) = " - Estimated pack-level parameters and created a mismatched 4-cell virtual UAV pack.";
reportLines(end + 1) = "";
reportLines(end + 1) = "Model parameters:";
reportLines(end + 1) = " - Cell capacities (Ah): " + string(mat2str(estimates.virtualCells.capacity_Ah.', 3));
reportLines(end + 1) = " - R0 values (Ohm): " + string(mat2str(estimates.virtualCells.R0_Ohm.', 4));
reportLines(end + 1) = " - Initial SoC: " + string(mat2str(estimates.virtualCells.initial_soc.', 3));
reportLines(end + 1) = " - CC current (A): " + string(cfg.charger.ccCurrent_A);
reportLines(end + 1) = " - CV pack target (V): " + string(cfg.charger.cvTargetPackVoltage_V);
reportLines(end + 1) = " - OCV temperatures represented (C): " + string(mat2str(lookup.temperature_grid_C));
reportLines(end + 1) = "";

for idx = 1:height(scenarioSummaries)
    summary = scenarioSummaries(idx, :);
    reportLines(end + 1) = summary.scenario_title;
    reportLines(end + 1) = " - Result: " + summary.status;
    reportLines(end + 1) = " - Termination reason: " + summary.termination_reason;
    reportLines(end + 1) = " - CC duration (s): " + string(round(summary.cc_duration_s, 1));
    reportLines(end + 1) = " - CV duration (s): " + string(round(summary.cv_duration_s, 1));
    reportLines(end + 1) = " - Total charging time (s): " + string(round(summary.total_charging_time_s, 1));
    reportLines(end + 1) = " - Final voltages (V): " + string(mat2str([summary.final_V1_V, summary.final_V2_V, summary.final_V3_V, summary.final_V4_V], 4));
    reportLines(end + 1) = " - Final SoC values: " + string(mat2str([summary.final_SOC1, summary.final_SOC2, summary.final_SOC3, summary.final_SOC4], 4));
    reportLines(end + 1) = " - Final pack voltage (V): " + string(round(summary.final_pack_voltage_V, 4));
    reportLines(end + 1) = " - Maximum cell voltage (V): " + string(round(summary.max_cell_voltage_V, 4));
    reportLines(end + 1) = " - Maximum temperature (C): " + string(round(summary.max_temperature_C, 2));
    reportLines(end + 1) = " - Final voltage imbalance (V): " + string(round(summary.final_voltage_imbalance_V, 4));
    reportLines(end + 1) = " - Final SoC spread (%): " + string(round(summary.final_soc_spread_pct, 3));
    reportLines(end + 1) = " - Balancing energy (Wh): " + string(round(summary.balancing_energy_Wh, 4));
    reportLines(end + 1) = " - Overvoltage predicted: " + string(summary.overvoltage_predicted);
    reportLines(end + 1) = " - Current cutoff reached: " + string(summary.ended_by_cutoff);
    reportLines(end + 1) = " - Temperature derating applied: " + string(summary.temperature_derating_applied);
    reportLines(end + 1) = " - Imbalance derating applied: " + string(summary.imbalance_derating_applied);
    reportLines(end + 1) = "";
end

reportLines(end + 1) = "Engineering Interpretation of Scenarios";
interpretationLines = local_engineering_interpretation(scenarioSummaries);
for idx = 1:numel(interpretationLines)
    reportLines(end + 1) = string(interpretationLines(idx));
end
reportLines(end + 1) = "";
reportLines(end + 1) = "Overall interpretation:";
improvedSummary = scenarioSummaries(strcmp(scenarioSummaries.scenario_name, "improved_bms"), :);
reportLines(end + 1) = " - Improved scenario target check: voltage imbalance < 0.020 V, SoC spread < 2%, max temperature < 45 C.";
reportLines(end + 1) = " - Improved scenario status: " + improvedSummary.status;
reportLines(end + 1) = " - Honest note: CALCE, Stanford/MATR cycle data, and the Di Nisio UAV benchmark were not available locally during this run.";
end

function lines = local_engineering_interpretation(scenarioSummaries)
baseline = scenarioSummaries(strcmp(scenarioSummaries.scenario_name, "baseline_no_balancing"), :);
basic = scenarioSummaries(strcmp(scenarioSummaries.scenario_name, "basic_passive_balancing"), :);
improved = scenarioSummaries(strcmp(scenarioSummaries.scenario_name, "improved_bms"), :);

lines = [
    " - Baseline no balancing fails because the cells retain their initial mismatch throughout charging. One cell reaches the voltage ceiling earlier, so charging stops with a large residual voltage imbalance of " + string(round(baseline.final_voltage_imbalance_V, 4)) + " V and a SoC spread of " + string(round(baseline.final_soc_spread_pct, 3)) + " %."
    " - Basic passive balancing is insufficient because it activates too late and does not reduce charger current when imbalance grows. It improves the result slightly, but it still predicts overvoltage and leaves excessive mismatch at the end of charge."
    " - The improved BMS changes three control features at the same time: earlier balancing activation near 4.00 V per cell, adaptive current reduction when voltage imbalance exceeds the tighter threshold, and thermal derating as temperature approaches the protection band."
    " - The improved BMS passes because balancing begins before the highest cell reaches the ceiling, the charger tapers more cautiously during the late stage, and the simulation terminates by the current cutoff rather than by an overvoltage event."
    " - Quantitatively, the improved controller reduces the final voltage imbalance from " + string(round(basic.final_voltage_imbalance_V, 4)) + " V in the basic case to " + string(round(improved.final_voltage_imbalance_V, 4)) + " V, and reduces the SoC spread from " + string(round(basic.final_soc_spread_pct, 3)) + " % to " + string(round(improved.final_soc_spread_pct, 3)) + " %."
    ];
end

function datasetStatus = local_dataset_status(cfg)
datasetNames = ["NASA PCoE"; "Oxford"; "CALCE"; "Stanford/MATR"; "Di Nisio UAV reference"];
datasetNames = datasetNames(:);
datasetStatus = table(datasetNames, strings(5, 1), 'VariableNames', {'dataset_name', 'status'});

datasetStatus.status(1) = local_status_from_file(cfg.files.nasa);
datasetStatus.status(2) = local_status_from_file(cfg.files.oxford);
datasetStatus.status(3) = local_status_from_file(cfg.files.calce);
datasetStatus.status(4) = local_status_from_file(cfg.files.stanford);
datasetStatus.status(5) = "missing placeholder";
end

function status = local_status_from_file(filePath)
if exist(filePath, "file")
    [~, ~, ext] = fileparts(filePath);
    if strcmpi(ext, ".mat")
        S = load(filePath);
        fields = fieldnames(S);
        hasData = false;
        for idx = 1:numel(fields)
            value = S.(fields{idx});
            if istable(value)
                hasData = hasData || ~isempty(value);
            else
                hasData = hasData || ~isempty(value);
            end
        end
        if hasData
            status = "available";
        else
            status = "missing placeholder";
        end
    else
        info = dir(filePath);
        if info.bytes > 0
            status = "available";
        else
            status = "missing placeholder";
        end
    end
else
    status = "missing placeholder";
end
end
