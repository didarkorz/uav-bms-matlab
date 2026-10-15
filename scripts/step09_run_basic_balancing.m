%% 09_run_basic_balancing.m
% Simulate CC-CV charging with basic passive balancing.

cfg = bms_load_cfg();
if ~exist(cfg.files.packModel, "file")
    run(fullfile(cfg.paths.scripts, "step07_build_4s_pack_model.m"));
end

S = load(cfg.files.packModel, "packModel");
scenarios = bms_get_scenarios(cfg);
results = bms_run_charging_scenario(S.packModel, scenarios(2), cfg);
summary = bms_summarize_results(results, cfg);

save(fullfile(cfg.paths.results, "basic_passive_balancing.mat"), "results", "summary");
writetable(bms_results_to_table(results), fullfile(cfg.paths.results, "basic_passive_balancing_timeseries.csv"));

disp(summary);
