%% run_bms_simulation.m
% Main MATLAB-only simulation runner for the diploma thesis project.
% This file is useful when a quick result is needed without opening Simulink.

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
run(fullfile(projectRoot, "config", "init_bms_project.m"));

results = simulate_bms_charge(cfg);
plot_bms_results(results, cfg);
reportOptions.projectRoot = projectRoot;
reportOptions.outputFolder = fullfile(projectRoot, cfg.output.resultsFolder);
reportOptions.modelName = "MATLAB Discrete BMS Charging Model";
reportOptions.simulationType = "MATLAB";
reportOptions.solver = "Fixed-step discrete script model";
reportOptions.sampleTime_s = cfg.sim.sampleTime_s;
reportOptions.notes = "Console report generated from MATLAB-only BMS charging simulation.";

report = generate_simulation_report(results, cfg, reportOptions); %#ok<NASGU>

disp("Simulation completed.");
disp("Exported report files:");
disp(report.exportPaths);
