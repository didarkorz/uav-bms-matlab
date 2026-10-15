function exportPaths = export_simulation_results(results, metrics, reportText, reportOptions)
%EXPORT_SIMULATION_RESULTS Thin wrapper for compatibility with thesis scripts.
% The main export implementation lives inside generate_simulation_report.

exportPaths = generate_simulation_report_export_only(results, metrics, reportText, reportOptions);
end

function exportPaths = generate_simulation_report_export_only(results, metrics, reportText, reportOptions)
outputFolder = reportOptions.outputFolder;
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

reportTxtPath = fullfile(outputFolder, "simulation_report.txt");
resultsCsvPath = fullfile(outputFolder, "simulation_results.csv");
summaryCsvPath = fullfile(outputFolder, "summary_metrics.csv");

fileId = fopen(reportTxtPath, "w");
if fileId < 0
    error("Unable to write report file: %s", reportTxtPath);
end
cleanupObj = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, "%s", reportText);

metricName = {
    "simulation_duration_s"
    "sample_time_s"
    "nominal_pack_voltage_V"
    "max_pack_voltage_V"
    "capacity_Ah"
    "cc_duration_s"
    "cv_duration_s"
    "total_charging_time_s"
    "max_current_A"
    "avg_current_A"
    "final_current_A"
    "final_pack_voltage_V"
    "final_average_soc_percent"
    "max_temperature_C"
    "final_voltage_imbalance_V"
    "balancing_energy_J"
    "efficiency_percent"
    "warning_count"
    };

value = [
    metrics.metadata.simulationDuration_s
    metrics.metadata.sampleTime_s
    metrics.parameters.nominalPackVoltage_V
    metrics.parameters.maxPackVoltage_V
    metrics.parameters.capacity_Ah
    metrics.charging.ccDuration_s
    metrics.charging.cvDuration_s
    metrics.charging.totalChargingTime_s
    metrics.charging.maxCurrent_A
    metrics.charging.averageCurrent_A
    metrics.charging.finalCurrent_A
    metrics.charging.finalPackVoltage_V
    100 * metrics.charging.finalAverageSoC
    max(metrics.temperature.maxTemperaturePerCell_C)
    metrics.balancing.finalImbalance_V
    metrics.balancing.energyDissipated_J
    metrics.performance.approximateEfficiency_percent
    metrics.performance.safetyWarningsCount
    ];

unit = {
    "s"
    "s"
    "V"
    "V"
    "Ah"
    "s"
    "s"
    "s"
    "A"
    "A"
    "A"
    "V"
    "percent"
    "degC"
    "V"
    "J"
    "percent"
    "count"
    };

summaryTable = table(metricName, value, unit);
writetable(summaryTable, summaryCsvPath);

if isfield(results, "time_s") && ~isempty(results.time_s)
    T = table(results.time_s(:), 'VariableNames', {'time_s'});

    if isfield(results, "cellVoltage_V") && size(results.cellVoltage_V, 1) == height(T)
        for idx = 1:size(results.cellVoltage_V, 2)
            T.(sprintf("cellVoltage_%d", idx)) = results.cellVoltage_V(:, idx);
        end
    end

    if isfield(results, "packVoltage_V") && numel(results.packVoltage_V) == height(T)
        T.packVoltage_V = results.packVoltage_V(:);
    end

    if isfield(results, "chargeCurrent_A") && numel(results.chargeCurrent_A) == height(T)
        T.chargeCurrent_A = results.chargeCurrent_A(:);
    end

    if isfield(results, "soc") && size(results.soc, 1) == height(T)
        for idx = 1:size(results.soc, 2)
            T.(sprintf("soc_%d", idx)) = results.soc(:, idx);
        end
    end

    if isfield(results, "temperature_C") && size(results.temperature_C, 1) == height(T)
        for idx = 1:size(results.temperature_C, 2)
            T.(sprintf("temperature_%d", idx)) = results.temperature_C(:, idx);
        end
    end

    if isfield(results, "balanceSignal") && size(results.balanceSignal, 1) == height(T)
        for idx = 1:size(results.balanceSignal, 2)
            T.(sprintf("balanceSignal_%d", idx)) = double(results.balanceSignal(:, idx));
        end
    end

    writetable(T, resultsCsvPath);
else
    writetable(table(), resultsCsvPath);
end

exportPaths.reportTxt = reportTxtPath;
exportPaths.resultsCsv = resultsCsvPath;
exportPaths.summaryCsv = summaryCsvPath;
end
