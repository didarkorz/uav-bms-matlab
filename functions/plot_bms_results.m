function plot_bms_results(results, cfg)
%PLOT_BMS_RESULTS Generate thesis-ready figures for the BMS charging study.

time_min = results.time_s / 60;
cellLabels = compose("Cell %d", 1:cfg.pack.numCells);

figure("Name", "Cell Voltages");
plot(time_min, results.cellVoltage_V, "LineWidth", 1.5);
grid on;
xlabel("Time (min)");
ylabel("Cell Voltage (V)");
title("4S LiPo Cell Voltages During Charging");
legend(cellLabels, "Location", "best");

figure("Name", "Pack Voltage and Charging Current");
yyaxis left;
plot(time_min, results.packVoltage_V, "LineWidth", 1.6);
ylabel("Pack Voltage (V)");
yyaxis right;
plot(time_min, results.chargeCurrent_A, "--", "LineWidth", 1.6);
ylabel("Charging Current (A)");
grid on;
xlabel("Time (min)");
title("CC-CV Charging Profile");
legend("Pack Voltage", "Charging Current", "Location", "best");

figure("Name", "State of Charge");
plot(time_min, 100 * results.soc, "LineWidth", 1.5);
grid on;
xlabel("Time (min)");
ylabel("SoC (%)");
title("Estimated State of Charge of Each Cell");
legend(cellLabels, "Location", "best");

figure("Name", "Cell Temperature");
plot(time_min, results.temperature_C, "LineWidth", 1.5);
grid on;
xlabel("Time (min)");
ylabel("Temperature (degC)");
title("Simplified Cell Thermal Response");
legend(cellLabels, "Location", "best");

figure("Name", "Balancing Signals");
stairs(time_min, double(results.balanceSignal), "LineWidth", 1.3);
grid on;
xlabel("Time (min)");
ylabel("Balancing Command");
title("Passive Balancing Activation");
legend(cellLabels, "Location", "best");
ylim([-0.1 1.1]);

if cfg.output.saveFigures
    if ~isfolder(cfg.output.resultsFolder)
        mkdir(cfg.output.resultsFolder);
    end

    figureHandles = findall(groot, "Type", "figure");
    for idx = 1:numel(figureHandles)
        fig = figureHandles(idx);
        fileName = fullfile(cfg.output.resultsFolder, fig.Name + "." + cfg.output.figureFormat);
        exportgraphics(fig, fileName, "Resolution", 300);
    end
end
end
