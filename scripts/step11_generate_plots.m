%% 11_generate_plots.m
% Generate thesis-ready plots for all three scenarios.

cfg = bms_load_cfg();
if ~exist(cfg.files.scenarioBundle, "file")
    run(fullfile(cfg.paths.scripts, "step10_run_improved_bms.m"));
end

S = load(cfg.files.scenarioBundle, "scenarioResults", "scenarioSummaries");
names = fieldnames(S.scenarioResults);
colors = lines(4);

resultsList = cell(numel(names), 1);
for idx = 1:numel(names)
    resultsList{idx} = S.scenarioResults.(names{idx});
end

local_plot_cells(resultsList, names, colors, cfg, "cell_voltages_vs_time", "Cell voltages vs time (V)", "Voltage (V)", "cell_voltage_V");
local_plot_pack(resultsList, names, cfg);
local_plot_cells(resultsList, names, colors, cfg, "soc_vs_time", "SoC per cell vs time", "SoC (-)", "soc");
local_plot_cells(resultsList, names, colors, cfg, "temperature_vs_time", "Temperature per cell vs time (C)", "Temperature (C)", "temperature_C");
local_plot_cells(resultsList, names, colors, cfg, "balancing_activation", "Balancing activation signals", "Balance ON (0/1)", "balance_signal");
local_plot_comparison_bar(S.scenarioSummaries.scenario_name, S.scenarioSummaries.final_voltage_imbalance_V, cfg, ...
    "final_voltage_imbalance_comparison", "Final voltage imbalance comparison", "Voltage imbalance (V)");
local_plot_comparison_bar(S.scenarioSummaries.scenario_name, S.scenarioSummaries.final_soc_spread_pct, cfg, ...
    "final_soc_spread_comparison", "Final SoC spread comparison", "SoC spread (%)");

fprintf("Saved plot files in %s\n", cfg.paths.results);

function local_plot_cells(resultsList, names, colors, cfg, fileStem, plotTitle, yLabelText, fieldName)
fig = figure("Name", plotTitle, "Color", "w");
for idx = 1:numel(resultsList)
    subplot(numel(resultsList), 1, idx);
    hold on;
    Y = double(resultsList{idx}.(fieldName));
    for cellIdx = 1:size(Y, 2)
        plot(resultsList{idx}.time_s ./ 60, Y(:, cellIdx), "LineWidth", 1.2, "Color", colors(cellIdx, :));
    end
    grid on;
    title(strrep(names{idx}, "_", " "));
    ylabel(yLabelText);
    if idx == numel(resultsList)
        xlabel("Time (min)");
    end
end
legend("Cell 1", "Cell 2", "Cell 3", "Cell 4", "Location", "bestoutside");
if cfg.reporting.saveFigures
    saveas(fig, fullfile(cfg.paths.results, fileStem + "." + cfg.reporting.figureFormat));
end
end

function local_plot_pack(resultsList, names, cfg)
fig = figure("Name", "Pack voltage and charging current", "Color", "w");
subplot(2, 1, 1);
hold on;
for idx = 1:numel(resultsList)
    plot(resultsList{idx}.time_s ./ 60, resultsList{idx}.pack_voltage_V, "LineWidth", 1.4);
end
grid on;
title("Pack voltage vs time");
ylabel("Pack voltage (V)");
legend(strrep(names, "_", " "), "Location", "best");

subplot(2, 1, 2);
hold on;
for idx = 1:numel(resultsList)
    plot(resultsList{idx}.time_s ./ 60, resultsList{idx}.charge_current_A, "LineWidth", 1.4);
end
grid on;
title("Charging current vs time");
xlabel("Time (min)");
ylabel("Current (A)");
legend(strrep(names, "_", " "), "Location", "best");

if cfg.reporting.saveFigures
    saveas(fig, fullfile(cfg.paths.results, "pack_voltage_and_current." + cfg.reporting.figureFormat));
end
end

function local_plot_comparison_bar(labels, values, cfg, fileStem, plotTitle, yLabelText)
fig = figure("Name", plotTitle, "Color", "w");
bar(categorical(cellstr(labels)), values, 0.55);
grid on;
title(plotTitle);
ylabel(yLabelText);
if cfg.reporting.saveFigures
    saveas(fig, fullfile(cfg.paths.results, fileStem + "." + cfg.reporting.figureFormat));
end
end
