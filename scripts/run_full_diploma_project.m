%% run_full_diploma_project.m
% End-to-end pipeline for the diploma BMS practical project.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
scriptNames = {
    "step00_project_setup.m"
    "step01_import_nasa.m"
    "step02_import_oxford.m"
    "step03_import_calce.m"
    "step04_import_stanford.m"
    "step05_build_ocv_soc_table.m"
    "step06_estimate_cell_parameters.m"
    "step07_build_4s_pack_model.m"
    "step08_run_baseline_no_balancing.m"
    "step09_run_basic_balancing.m"
    "step10_run_improved_bms.m"
    "step11_generate_plots.m"
    "step12_generate_report.m"
    "step13_validate_model_against_data.m"
    };

for idx = 1:numel(scriptNames)
    run(fullfile(projectRoot, "scripts", scriptNames{idx}));
end

cfg = bms_load_cfg();
nasaRows = local_table_rows(cfg.files.nasa, "nasaTable");
oxfordRows = local_table_rows(cfg.files.oxford, "oxfordTable");

scenarioSummary = readtable(fullfile(cfg.paths.results, "scenario_comparison_summary.csv"));
validationMetrics = readtable(cfg.files.validation);

baseline = scenarioSummary(strcmp(scenarioSummary.scenario_name, "baseline_no_balancing"), :);
basic = scenarioSummary(strcmp(scenarioSummary.scenario_name, "basic_passive_balancing"), :);
improved = scenarioSummary(strcmp(scenarioSummary.scenario_name, "improved_bms"), :);

fprintf("\nFINAL DIPLOMA PIPELINE SUMMARY\n");
fprintf("NASA rows imported: %d\n", nasaRows);
fprintf("Oxford rows imported: %d\n", oxfordRows);
fprintf("Validation RMSE: %.4f V\n", validationMetrics.rmse_voltage_V(1));
fprintf("Baseline result: %s (%s)\n", baseline.status{1}, baseline.termination_reason{1});
fprintf("Basic result: %s (%s)\n", basic.status{1}, basic.termination_reason{1});
fprintf("Improved result: %s (%s)\n", improved.status{1}, improved.termination_reason{1});
fprintf("Final recommendation for diploma: Present the improved BMS as the recommended charging strategy, explain why the baseline and late-balancing cases fail, and state clearly that validation is dataset-based rather than hardware-based.\n");

function n = local_table_rows(filePath, varName)
n = 0;
if ~exist(filePath, "file")
    return;
end
S = load(filePath, varName);
if isfield(S, varName) && istable(S.(varName))
    n = height(S.(varName));
end
end
