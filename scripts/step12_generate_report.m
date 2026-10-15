%% step12_generate_report.m
% Executable report-generation step for the full diploma pipeline.

cfg = bms_load_cfg();
reportText = bms_generate_report_outputs(cfg);
fprintf("%s\n", reportText);
fprintf("Saved report to %s\n", fullfile(cfg.paths.reports, "simulation_report.txt"));
fprintf("Saved scenario summary to %s\n", fullfile(cfg.paths.results, "scenario_comparison_summary.csv"));
fprintf("Saved parameter audit to %s\n", cfg.files.parameterAudit);
