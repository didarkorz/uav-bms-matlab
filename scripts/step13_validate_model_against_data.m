%% step13_validate_model_against_data.m
% Executable validation step for the full diploma pipeline.

cfg = bms_load_cfg();
[validationMetrics, validationSeries] = bms_run_model_validation(cfg);

writetable(validationMetrics, cfg.files.validation);

fig = figure("Name", "Model vs measured voltage", "Color", "w");
plot(validationSeries.time_s ./ 60, validationSeries.measured_voltage_V, "LineWidth", 1.5);
hold on;
plot(validationSeries.time_s ./ 60, validationSeries.simulated_voltage_V, "--", "LineWidth", 1.5);
grid on;
xlabel("Time (min)");
ylabel("Voltage (V)");
title("Measured versus simulated cell voltage");
legend("Measured", "Simulated", "Location", "best");
saveas(fig, fullfile(cfg.paths.results, "model_vs_measured_voltage." + cfg.reporting.figureFormat));

bms_write_diploma_draft(cfg, validationMetrics);

disp(validationMetrics);
fprintf("Saved validation metrics to %s\n", cfg.files.validation);
fprintf("Saved validation figure to %s\n", fullfile(cfg.paths.results, "model_vs_measured_voltage." + cfg.reporting.figureFormat));
fprintf("Saved diploma draft to %s\n", cfg.files.diplomaDraft);
