%% 10_run_improved_bms.m
% Simulate the improved BMS and compare it with baseline/basic scenarios.
% The improved controller is intentionally explainable for thesis defense:
% 1. Passive balancing starts earlier than in the basic controller.
% 2. Charging current is reduced if cell imbalance grows too large.
% 3. Charging current is also reduced as temperature approaches the limit.
% 4. Charging ends only when CV taper reaches the current cutoff.

cfg = bms_load_cfg();

requiredFiles = {
    fullfile(cfg.paths.results, "baseline_no_balancing.mat"), "step08_run_baseline_no_balancing.m"
    fullfile(cfg.paths.results, "basic_passive_balancing.mat"), "step09_run_basic_balancing.m"
    };

for idx = 1:size(requiredFiles, 1)
    if ~exist(requiredFiles{idx, 1}, "file")
        run(fullfile(cfg.paths.scripts, requiredFiles{idx, 2}));
    end
end

if ~exist(cfg.files.packModel, "file")
    run(fullfile(cfg.paths.scripts, "step07_build_4s_pack_model.m"));
end

S = load(cfg.files.packModel, "packModel");
scenarios = bms_get_scenarios(cfg);
improvedResults = bms_run_charging_scenario(S.packModel, scenarios(3), cfg);
improvedSummary = bms_summarize_results(improvedResults, cfg);
results = improvedResults; %#ok<NASGU>
summary = improvedSummary; %#ok<NASGU>
save(fullfile(cfg.paths.results, "improved_bms.mat"), "improvedResults", "improvedSummary", "results", "summary");
writetable(bms_results_to_table(improvedResults), fullfile(cfg.paths.results, "improved_bms_timeseries.csv"));

baselineData = load(fullfile(cfg.paths.results, "baseline_no_balancing.mat"));
basicData = load(fullfile(cfg.paths.results, "basic_passive_balancing.mat"));

scenarioResults = struct();
scenarioResults.baseline = baselineData.results;
scenarioResults.basic = basicData.results;
scenarioResults.improved = improvedResults;

scenarioSummaries = [baselineData.summary; basicData.summary; improvedSummary];
save(cfg.files.scenarioBundle, "scenarioResults", "scenarioSummaries");
writetable(scenarioSummaries, fullfile(cfg.paths.results, "scenario_comparison_summary.csv"));

disp(scenarioSummaries(:, {'scenario_name', 'status', 'final_voltage_imbalance_V', 'final_soc_spread_pct', 'max_temperature_C', 'overvoltage_predicted', 'ended_by_cutoff', 'termination_reason'}));
