function plot_scenario_comparison(studies, cfg, outputFolder)
%PLOT_SCENARIO_COMPARISON Generate thesis-ready comparison figures for the
% three engineering scenarios.

if nargin < 3 || strlength(string(outputFolder)) == 0
    outputFolder = fullfile(pwd, cfg.output.resultsFolder);
end

scenarioNames = strings(numel(studies), 1);
for idx = 1:numel(studies)
    scenarioNames(idx) = studies(idx).name;
end

cellColors = lines(cfg.pack.numCells);
scenarioStyles = ["-", "--", ":"];

figure("Name", "Scenario Comparison - Cell Voltages");
hold on;
for scenarioIdx = 1:numel(studies)
    time_min = studies(scenarioIdx).results.time_s / 60;
    for cellIdx = 1:cfg.pack.numCells
        plot(time_min, studies(scenarioIdx).results.cellVoltage_V(:, cellIdx), ...
            "LineStyle", scenarioStyles(min(scenarioIdx, numel(scenarioStyles))), ...
            "Color", cellColors(cellIdx, :), "LineWidth", 1.3);
    end
end
grid on;
xlabel("Time (min)");
ylabel("Cell Voltage (V)");
title("Cell Voltages vs Time Across Engineering Scenarios");
legend(build_cell_scenario_legend(scenarioNames, cfg.pack.numCells), "Location", "eastoutside");
hold off;

figure("Name", "Scenario Comparison - Charging Current");
hold on;
for scenarioIdx = 1:numel(studies)
    plot(studies(scenarioIdx).results.time_s / 60, studies(scenarioIdx).results.chargeCurrent_A, ...
        "LineStyle", scenarioStyles(min(scenarioIdx, numel(scenarioStyles))), "LineWidth", 1.8);
end
grid on;
xlabel("Time (min)");
ylabel("Charging Current (A)");
title("Charging Current vs Time");
legend(scenarioNames, "Location", "best");
hold off;

figure("Name", "Scenario Comparison - SoC");
hold on;
for scenarioIdx = 1:numel(studies)
    meanSoc_percent = 100 * mean(studies(scenarioIdx).results.soc, 2);
    plot(studies(scenarioIdx).results.time_s / 60, meanSoc_percent, ...
        "LineStyle", scenarioStyles(min(scenarioIdx, numel(scenarioStyles))), "LineWidth", 1.8);
end
grid on;
xlabel("Time (min)");
ylabel("Average SoC (%)");
title("Average SoC vs Time");
legend(scenarioNames, "Location", "best");
hold off;

figure("Name", "Scenario Comparison - Temperature");
hold on;
for scenarioIdx = 1:numel(studies)
    maxTemp_C = max(studies(scenarioIdx).results.temperature_C, [], 2);
    plot(studies(scenarioIdx).results.time_s / 60, maxTemp_C, ...
        "LineStyle", scenarioStyles(min(scenarioIdx, numel(scenarioStyles))), "LineWidth", 1.8);
end
grid on;
xlabel("Time (min)");
ylabel("Maximum Cell Temperature (degC)");
title("Temperature vs Time");
legend(scenarioNames, "Location", "best");
hold off;

finalImbalance_V = zeros(numel(studies), 1);
finalSocSpread_percent = zeros(numel(studies), 1);
for scenarioIdx = 1:numel(studies)
    finalImbalance_V(scenarioIdx) = studies(scenarioIdx).report.metrics.balancing.finalImbalance_V;
    finalSocSpread_percent(scenarioIdx) = studies(scenarioIdx).report.metrics.performance.finalSoCSpread_percent;
end

figure("Name", "Scenario Comparison - Final Imbalance");
bar(categorical(cellstr(scenarioNames)), finalImbalance_V, 0.55);
grid on;
ylabel("Final Voltage Imbalance (V)");
title("Final Cell Voltage Imbalance Comparison");

figure("Name", "Scenario Comparison - Final SoC Spread");
bar(categorical(cellstr(scenarioNames)), finalSocSpread_percent, 0.55);
grid on;
ylabel("Final SoC Spread (%)");
title("Final SoC Spread Comparison");

if cfg.output.saveFigures
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    figureHandles = findall(groot, "Type", "figure");
    for idx = 1:numel(figureHandles)
        fig = figureHandles(idx);
        fileName = fullfile(outputFolder, matlab.lang.makeValidName(fig.Name) + "." + cfg.output.figureFormat);
        exportgraphics(fig, fileName, "Resolution", 300);
    end
end
end

function labels = build_cell_scenario_legend(scenarioNames, numCells)
labels = strings(numel(scenarioNames) * numCells, 1);
cursor = 1;
for scenarioIdx = 1:numel(scenarioNames)
    for cellIdx = 1:numCells
        labels(cursor) = scenarioNames(scenarioIdx) + " - Cell " + cellIdx;
        cursor = cursor + 1;
    end
end
end
