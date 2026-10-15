function report = generate_simulation_report(results, cfg, reportOptions)
%GENERATE_SIMULATION_REPORT Print, validate, and export a thesis-ready report.
% This function is designed to be robust for both MATLAB-only and Simulink
% workflows. If a signal is missing from the result structure, the report
% prints "Not available in current model" instead of failing.

if nargin < 3
    reportOptions = struct();
end

reportOptions = apply_report_defaults(reportOptions, cfg);
metrics = collect_report_metrics(results, cfg, reportOptions);
reportText = build_report_text(metrics, cfg, reportOptions);

fprintf("%s", reportText);

exportPaths = export_simulation_results(results, metrics, reportText, reportOptions);

report.metrics = metrics;
report.text = reportText;
report.exportPaths = exportPaths;
end

function reportOptions = apply_report_defaults(reportOptions, cfg)
if ~isfield(reportOptions, "projectRoot") || strlength(string(reportOptions.projectRoot)) == 0
    reportOptions.projectRoot = pwd;
end

if ~isfield(reportOptions, "outputFolder") || strlength(string(reportOptions.outputFolder)) == 0
    reportOptions.outputFolder = fullfile(reportOptions.projectRoot, cfg.output.resultsFolder);
end

if ~isfield(reportOptions, "modelName") || strlength(string(reportOptions.modelName)) == 0
    reportOptions.modelName = "MATLAB Discrete Simulation";
end

if ~isfield(reportOptions, "simulationType") || strlength(string(reportOptions.simulationType)) == 0
    reportOptions.simulationType = "MATLAB";
end

if ~isfield(reportOptions, "solver") || strlength(string(reportOptions.solver)) == 0
    reportOptions.solver = "Not available in current model";
end

if ~isfield(reportOptions, "sampleTime_s") || isempty(reportOptions.sampleTime_s)
    reportOptions.sampleTime_s = cfg.sim.sampleTime_s;
end

if ~isfield(reportOptions, "simulationDateTime")
    reportOptions.simulationDateTime = datetime("now");
end

if ~isfield(reportOptions, "notes")
    reportOptions.notes = "";
end
end

function metrics = collect_report_metrics(results, cfg, reportOptions)
time_s = force_column(get_optional_signal(results, "time_s"));
cellVoltage_V = force_matrix(get_optional_signal(results, "cellVoltage_V"), cfg.pack.numCells);
packVoltage_V = force_column(get_optional_signal(results, "packVoltage_V"));
chargeCurrent_A = force_column(get_optional_signal(results, "chargeCurrent_A"));
soc = force_matrix(get_optional_signal(results, "soc"), cfg.pack.numCells);
temperature_C = force_matrix(get_optional_signal(results, "temperature_C"), cfg.pack.numCells);
balanceSignal = force_matrix(get_optional_signal(results, "balanceSignal"), cfg.pack.numCells);
bleedCurrent_A = force_matrix(get_optional_signal(results, "bleedCurrent_A"), cfg.pack.numCells);
chargerMode = normalize_string_signal(get_optional_signal(results, "chargerMode"));
protectionActive = force_column(get_optional_signal(results, "protectionActive"));
terminationReasonSignal = normalize_string_signal(get_optional_signal(results, "terminationReason"));
packImbalance_V = force_column(get_optional_signal(results, "packImbalance_V"));

if isempty(time_s)
    time_s = cfg.sim.time_s(:);
end

if isempty(packImbalance_V) && ~isempty(cellVoltage_V)
    packImbalance_V = max(cellVoltage_V, [], 2) - min(cellVoltage_V, [], 2);
end

dt_s = infer_sample_time(time_s, reportOptions.sampleTime_s);

initialCellVoltage_V = ocv_from_soc(cfg.init.soc(:).');
initialImbalance_V = max(initialCellVoltage_V) - min(initialCellVoltage_V);

metrics.metadata.simulationDateTime = reportOptions.simulationDateTime;
metrics.metadata.modelName = string(reportOptions.modelName);
metrics.metadata.simulationType = string(reportOptions.simulationType);
metrics.metadata.simulationDuration_s = safe_last(time_s);
metrics.metadata.sampleTime_s = dt_s;
metrics.metadata.solver = string(reportOptions.solver);
metrics.metadata.matlabVersion = string(version);
metrics.metadata.simulinkVersion = get_simulink_version_safe();
metrics.metadata.notes = string(reportOptions.notes);

metrics.parameters.numCells = cfg.pack.numCells;
metrics.parameters.nominalCellVoltage_V = cfg.pack.nominalCellVoltage_V;
metrics.parameters.maxCellVoltage_V = cfg.pack.maxCellVoltage_V;
metrics.parameters.minSafeCellVoltage_V = cfg.pack.minCellVoltage_V;
metrics.parameters.nominalPackVoltage_V = cfg.pack.nominalPackVoltage_V;
metrics.parameters.maxPackVoltage_V = cfg.pack.numCells * cfg.pack.maxCellVoltage_V;
metrics.parameters.capacity_Ah = cfg.pack.capacity_Ah;
metrics.parameters.initialSoC = cfg.init.soc(:).';
metrics.parameters.internalResistance_Ohm = cfg.cell.internalResistance_Ohm(:).';
metrics.parameters.initialCellVoltage_V = initialCellVoltage_V;
metrics.parameters.initialImbalance_V = initialImbalance_V;

metrics.charging.ccDuration_s = sum(chargerMode == "CC") * dt_s;
metrics.charging.cvDuration_s = sum(chargerMode == "CV") * dt_s;
metrics.charging.totalChargingTime_s = safe_last(time_s);
metrics.charging.maxCurrent_A = safe_max(chargeCurrent_A);
metrics.charging.averageCurrent_A = safe_mean(chargeCurrent_A);
metrics.charging.finalCurrent_A = safe_last(chargeCurrent_A);
metrics.charging.finalPackVoltage_V = safe_last(packVoltage_V);
metrics.charging.finalCellVoltages_V = safe_last_row(cellVoltage_V);
metrics.charging.finalSoC = safe_last_row(soc);
metrics.charging.finalAverageSoC = safe_mean(metrics.charging.finalSoC);
metrics.charging.terminationReason = "Not available in current model";
metrics.charging.currentCutoff_A = cfg.charge.terminationCurrent_A;
metrics.charging.actualCompletionTime_s = safe_last(time_s);
metrics.charging.cvCurrentDecayObserved = detect_cv_current_decay(chargerMode, chargeCurrent_A);

balanceActivated = any(balanceSignal(:) > 0.5);
metrics.balancing.activated = balanceActivated;
metrics.balancing.cellsBalanced = find(any(balanceSignal > 0.5, 1));
metrics.balancing.totalBalancingTime_s = sum(balanceSignal > 0.5, 1) * dt_s;
metrics.balancing.maxImbalanceBeforeBalancing_V = compute_pre_balance_imbalance(cellVoltage_V, balanceSignal);
metrics.balancing.maxImbalanceAfterCharging_V = compute_window_imbalance(cellVoltage_V, max(1, size(cellVoltage_V, 1) - 50), size(cellVoltage_V, 1));
metrics.balancing.finalImbalance_V = compute_final_spread(cellVoltage_V);
metrics.balancing.energyDissipated_J = compute_balance_energy(bleedCurrent_A, cfg.balance.resistor_Ohm, dt_s);
metrics.balancing.energyPerCell_J = compute_balance_energy_per_cell(bleedCurrent_A, cfg.balance.resistor_Ohm, dt_s);
metrics.balancing.resistor_Ohm = cfg.balance.resistor_Ohm;
metrics.balancing.threshold_V = cfg.balance.deltaTrigger_V;
metrics.balancing.maximumImbalance_V = safe_max(packImbalance_V);
metrics.balancing.initialImbalance_V = safe_first(packImbalance_V);

metrics.temperature.initialTemperature_C = cfg.init.temperature_C(:).';
metrics.temperature.maxTemperaturePerCell_C = safe_max_rowwise(temperature_C);
metrics.temperature.finalTemperaturePerCell_C = safe_last_row(temperature_C);
metrics.temperature.averageTemperature_C = safe_mean(temperature_C(:));
metrics.temperature.protectionTriggered = detect_overtemperature(temperature_C, cfg) || any(protectionActive > 0.5);
metrics.temperature.protectionTriggerTime_s = compute_first_threshold_time(time_s, max_by_row(temperature_C), cfg.safety.maxTemperature_C);
metrics.temperature.warningExceededSafeRange = detect_thermal_warning(temperature_C, cfg);
metrics.temperature.maxRiseAboveAmbient_C = safe_max(metrics.temperature.maxTemperaturePerCell_C - cfg.thermal.ambient_C);

metrics.safety.overvoltageDetected = any(cellVoltage_V(:) > cfg.pack.maxCellVoltage_V);
metrics.safety.undervoltageDetected = any(cellVoltage_V(:) < cfg.pack.minCellVoltage_V);
metrics.safety.overtemperatureDetected = detect_overtemperature(temperature_C, cfg);
metrics.safety.chargingStoppedBySafety = any(protectionActive > 0.5) || any(chargerMode == "STOP");
metrics.charging.terminationReason = determine_stop_reason(metrics, chargerMode, chargeCurrent_A, soc, cfg, terminationReasonSignal);
metrics.safety.stopReason = metrics.charging.terminationReason;

metrics.soc.initialSoC = cfg.init.soc(:).';
metrics.soc.finalSoC = safe_last_row(soc);
metrics.soc.minimumSoC = safe_min(soc(:));
metrics.soc.maximumSoC = safe_max(soc(:));
metrics.soc.method = "Coulomb counting with optional low-current voltage correction";
metrics.soc.driftDetected = any(soc(:) < -1e-6) || any(soc(:) > 1 + 1e-6);

metrics.performance.chargingCompletedSuccessfully = compute_success_flag(metrics, cfg);
metrics.performance.allCellsWithinSafeVoltageRange = all_in_range(metrics.charging.finalCellVoltages_V, cfg.pack.minCellVoltage_V, cfg.pack.maxCellVoltage_V);
metrics.performance.finalCellVoltageSpread_V = metrics.balancing.finalImbalance_V;
metrics.performance.finalSoCSpread_percent = 100 * compute_spread(metrics.charging.finalSoC);
metrics.performance.approximateEfficiency_percent = compute_efficiency(results, cfg, dt_s);
metrics.performance.realismAssessment = assess_realism(metrics, cfg);

validation = run_validation_checks(results, metrics, cfg);
metrics.validation = validation;
metrics.performance.safetyWarningsCount = numel(validation.warnings);
metrics.performance.overallResult = determine_overall_result(metrics);
metrics.performance.engineeringInterpretation = build_engineering_interpretation(metrics, cfg);
end

function exportPaths = export_simulation_results(results, metrics, reportText, reportOptions)
outputFolder = reportOptions.outputFolder;
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

reportTxtPath = fullfile(outputFolder, "simulation_report.txt");
resultsCsvPath = fullfile(outputFolder, "simulation_results.csv");
summaryCsvPath = fullfile(outputFolder, "summary_metrics.csv");

write_text_file(reportTxtPath, reportText);
write_summary_metrics_csv(summaryCsvPath, metrics);
write_time_series_csv(resultsCsvPath, results);

exportPaths.reportTxt = reportTxtPath;
exportPaths.resultsCsv = resultsCsvPath;
exportPaths.summaryCsv = summaryCsvPath;
end

function reportText = build_report_text(metrics, cfg, reportOptions)
lines = strings(0, 1);

lines(end+1) = "============================================================";
lines(end+1) = "UAV BMS SIMULATION REPORT";
lines(end+1) = "============================================================";
lines(end+1) = "";

lines(end+1) = "[1] Simulation Metadata";
lines = append_lines(lines, [
    format_line("Simulation date/time", string(metrics.metadata.simulationDateTime))
    format_line("Model name", metrics.metadata.modelName)
    format_line("Simulation type", metrics.metadata.simulationType)
    format_line("Simulation duration", format_duration(metrics.metadata.simulationDuration_s))
    format_line("Solver", metrics.metadata.solver)
    format_line("Sample time / step size", format_scalar(metrics.metadata.sampleTime_s, "s"))
    format_line("MATLAB version", metrics.metadata.matlabVersion)
    format_line("Simulink version", metrics.metadata.simulinkVersion)
    ]);

if strlength(metrics.metadata.notes) > 0
    lines(end+1) = format_line("Run notes", metrics.metadata.notes);
end
lines(end+1) = "";

lines(end+1) = "[2] Battery Pack Parameters";
lines = append_lines(lines, [
    format_line("Number of cells", format_scalar(metrics.parameters.numCells, ""))
    format_line("Nominal cell voltage", format_scalar(metrics.parameters.nominalCellVoltage_V, "V"))
    format_line("Maximum cell voltage", format_scalar(metrics.parameters.maxCellVoltage_V, "V"))
    format_line("Minimum safe cell voltage", format_scalar(metrics.parameters.minSafeCellVoltage_V, "V"))
    format_line("Nominal pack voltage", format_scalar(metrics.parameters.nominalPackVoltage_V, "V"))
    format_line("Maximum pack voltage", format_scalar(metrics.parameters.maxPackVoltage_V, "V"))
    format_line("Battery capacity", format_scalar(metrics.parameters.capacity_Ah, "Ah"))
    format_line("Initial SoC values", format_vector(metrics.parameters.initialSoC, "%"))
    format_line("Internal resistance per cell", format_vector(metrics.parameters.internalResistance_Ohm, "Ohm"))
    format_line("Initial cell voltage values", format_vector(metrics.parameters.initialCellVoltage_V, "V"))
    format_line("Initial cell imbalance", format_scalar(metrics.parameters.initialImbalance_V, "V"))
    ]);
lines(end+1) = "";

lines(end+1) = "[3] Charging Results";
lines = append_lines(lines, [
    format_line("CC stage duration", format_duration(metrics.charging.ccDuration_s))
    format_line("CV stage duration", format_duration(metrics.charging.cvDuration_s))
    format_line("Total charging time", format_duration(metrics.charging.totalChargingTime_s))
    format_line("Actual charging completion time", format_duration(metrics.charging.actualCompletionTime_s))
    format_line("Maximum charging current", format_scalar(metrics.charging.maxCurrent_A, "A"))
    format_line("Average charging current", format_scalar(metrics.charging.averageCurrent_A, "A"))
    format_line("Final charging current", format_scalar(metrics.charging.finalCurrent_A, "A"))
    format_line("Current cutoff value", format_scalar(metrics.charging.currentCutoff_A, "A"))
    format_line("CV current decay observed", yes_no(metrics.charging.cvCurrentDecayObserved))
    format_line("Final pack voltage", format_scalar(metrics.charging.finalPackVoltage_V, "V"))
    format_line("Final cell voltages", format_vector(metrics.charging.finalCellVoltages_V, "V"))
    format_line("Final SoC of each cell", format_vector(metrics.charging.finalSoC, "%"))
    format_line("Final average SoC", format_scalar(100 * metrics.charging.finalAverageSoC, "%"))
    format_line("Charge termination reason", metrics.charging.terminationReason)
    ]);
lines(end+1) = "";

lines(end+1) = "[4] Balancing Results";
lines = append_lines(lines, [
    format_line("Balancing activated", yes_no(metrics.balancing.activated))
    format_line("Cells balanced", format_index_vector(metrics.balancing.cellsBalanced))
    format_line("Total balancing time per cell", format_vector_seconds(metrics.balancing.totalBalancingTime_s))
    format_line("Balancing energy per cell", format_vector(metrics.balancing.energyPerCell_J, "J"))
    format_line("Initial voltage imbalance", format_scalar(metrics.balancing.initialImbalance_V, "V"))
    format_line("Maximum voltage imbalance during simulation", format_scalar(metrics.balancing.maximumImbalance_V, "V"))
    format_line("Maximum voltage imbalance before balancing", format_scalar(metrics.balancing.maxImbalanceBeforeBalancing_V, "V"))
    format_line("Maximum voltage imbalance after charging", format_scalar(metrics.balancing.maxImbalanceAfterCharging_V, "V"))
    format_line("Final voltage imbalance", format_scalar(metrics.balancing.finalImbalance_V, "V"))
    format_line("Estimated balancing energy dissipated", format_scalar(metrics.balancing.energyDissipated_J, "J"))
    format_line("Balancing resistor values", format_scalar(metrics.balancing.resistor_Ohm, "Ohm"))
    format_line("Balancing threshold", format_scalar(metrics.balancing.threshold_V, "V"))
    ]);
lines(end+1) = "";

lines(end+1) = "[5] Temperature Results";
lines = append_lines(lines, [
    format_line("Initial temperature", format_vector(metrics.temperature.initialTemperature_C, "degC"))
    format_line("Maximum temperature per cell", format_vector(metrics.temperature.maxTemperaturePerCell_C, "degC"))
    format_line("Final temperature per cell", format_vector(metrics.temperature.finalTemperaturePerCell_C, "degC"))
    format_line("Average temperature", format_scalar(metrics.temperature.averageTemperature_C, "degC"))
    format_line("Maximum temperature rise above ambient", format_scalar(metrics.temperature.maxRiseAboveAmbient_C, "degC"))
    format_line("Temperature protection triggered", yes_no(metrics.temperature.protectionTriggered))
    format_line("Time when protection triggered", format_duration(metrics.temperature.protectionTriggerTime_s))
    format_line("Thermal warning > 45 degC", yes_no(metrics.temperature.warningExceededSafeRange))
    ]);
lines(end+1) = "";

lines(end+1) = "[6] Safety Checks";
lines = append_lines(lines, [
    format_line("Overvoltage event detected", yes_no(metrics.safety.overvoltageDetected))
    format_line("Undervoltage event detected", yes_no(metrics.safety.undervoltageDetected))
    format_line("Overtemperature event detected", yes_no(metrics.safety.overtemperatureDetected))
    format_line("Charging stopped by safety logic", yes_no(metrics.safety.chargingStoppedBySafety))
    format_line("Reason for stop", metrics.safety.stopReason)
    format_line("Number of safety warnings", format_scalar(metrics.performance.safetyWarningsCount, ""))
    ]);

for idx = 1:numel(metrics.validation.warnings)
    lines(end+1) = "  Warning " + idx + ": " + string(metrics.validation.warnings(idx));
end

if isempty(metrics.validation.warnings)
    lines(end+1) = "  Warning summary: No validation warnings were raised.";
end
lines(end+1) = "";

lines(end+1) = "[7] SoC Estimation";
lines = append_lines(lines, [
    format_line("Initial SoC", format_vector(metrics.soc.initialSoC, "%"))
    format_line("Final SoC", format_vector(metrics.soc.finalSoC, "%"))
    format_line("Minimum SoC", format_scalar(100 * metrics.soc.minimumSoC, "%"))
    format_line("Maximum SoC", format_scalar(100 * metrics.soc.maximumSoC, "%"))
    format_line("SoC estimation method used", metrics.soc.method)
    format_line("SoC drift or unrealistic values detected", yes_no(metrics.soc.driftDetected))
    ]);
lines(end+1) = "";

lines(end+1) = "[8] Engineering Interpretation";
lines = append_lines(lines, [
    format_line("Charging completed successfully", yes_no(metrics.performance.chargingCompletedSuccessfully))
    format_line("All cells reached safe voltage range", yes_no(metrics.performance.allCellsWithinSafeVoltageRange))
    format_line("Final cell voltage spread", format_scalar(metrics.performance.finalCellVoltageSpread_V, "V"))
    format_line("Final SoC spread", format_scalar(metrics.performance.finalSoCSpread_percent, "%"))
    format_line("Approximate charging efficiency", format_scalar(metrics.performance.approximateEfficiency_percent, "%"))
    format_line("Realistic or idealized result", metrics.performance.realismAssessment)
    format_line("Engineering interpretation", metrics.performance.engineeringInterpretation)
    ]);
lines(end+1) = "";

lines(end+1) = "============================================================";
lines(end+1) = "COPY THIS REPORT TO ADVISOR";
lines(end+1) = "============================================================";
lines = append_lines(lines, [
    format_line("Final cell voltages", format_vector(metrics.charging.finalCellVoltages_V, "V"))
    format_line("Final SoC values", format_vector(metrics.charging.finalSoC, "%"))
    format_line("Maximum temperature", format_scalar(safe_max(metrics.temperature.maxTemperaturePerCell_C), "degC"))
    format_line("Total charging time", format_duration(metrics.charging.totalChargingTime_s))
    format_line("Final voltage imbalance", format_scalar(metrics.balancing.finalImbalance_V, "V"))
    format_line("Balancing activated", yes_no(metrics.balancing.activated))
    format_line("Safety warnings count", format_scalar(metrics.performance.safetyWarningsCount, ""))
    format_line("Overall result", metrics.performance.overallResult)
    ]);
lines(end+1) = "";

lines(end+1) = "============================================================";
lines(end+1) = "END OF REPORT";
lines(end+1) = "============================================================";

reportText = join(lines, newline) + newline;
end

function validation = run_validation_checks(results, metrics, cfg)
warnings = strings(0, 1);

cellVoltage_V = get_optional_signal(results, "cellVoltage_V");
temperature_C = get_optional_signal(results, "temperature_C");
soc = get_optional_signal(results, "soc");
chargeCurrent_A = get_optional_signal(results, "chargeCurrent_A");

if any_numeric_signal_exceeds(cellVoltage_V, cfg.pack.maxCellVoltage_V)
    warnings(end+1) = "At least one cell voltage exceeded 4.2 V.";
end

if any_numeric_signal_below(cellVoltage_V, cfg.pack.minCellVoltage_V)
    warnings(end+1) = "At least one cell voltage dropped below 3.0 V.";
end

if any_numeric_signal_exceeds(temperature_C, cfg.safety.derateTemperature_C)
    warnings(end+1) = "Temperature exceeded 45 degC safe warning threshold.";
end

if any_numeric_signal_below(soc, 0) || any_numeric_signal_exceeds(soc, 1)
    warnings(end+1) = "SoC left the physically valid 0 to 100 percent range.";
end

if ~isnan(metrics.balancing.finalImbalance_V) && metrics.balancing.finalImbalance_V > max(cfg.balance.deltaTrigger_V, 0.02)
    warnings(end+1) = "Final cell voltage imbalance remains high.";
end

if any_numeric_signal_below(chargeCurrent_A, -1e-6) || any_numeric_signal_exceeds(chargeCurrent_A, 1.2 * cfg.charge.ccCurrent_A)
    warnings(end+1) = "Charging current shows unrealistic behavior relative to the configured CC limit.";
end

if contains_nan_or_inf(results)
    warnings(end+1) = "Simulation output contains NaN or Inf values.";
end

validation.warnings = warnings;
validation.hasWarning = ~isempty(warnings);
end

function result = contains_nan_or_inf(inputStruct)
result = false;
fields = fieldnames(inputStruct);

for idx = 1:numel(fields)
    value = inputStruct.(fields{idx});
    if isnumeric(value) || islogical(value)
        if any(isnan(value(:)) | isinf(value(:)))
            result = true;
            return;
        end
    end
end
end

function text = build_engineering_interpretation(metrics, cfg)
if metrics.performance.chargingCompletedSuccessfully && metrics.performance.safetyWarningsCount == 0
    text = "Charging reached a safe final condition with a visible CC-CV transition, non-zero taper behavior, and a realistic residual cell mismatch.";
elseif metrics.performance.chargingCompletedSuccessfully
    text = "Charging reached the end condition, but at least one warning suggests the model parameters or logic should be reviewed before thesis presentation.";
elseif metrics.safety.chargingStoppedBySafety
    text = "Charging was interrupted by protection logic, indicating the BMS safety supervision responded to a potentially unsafe condition.";
elseif metrics.balancing.finalImbalance_V > cfg.balance.deltaTrigger_V
    text = "The pack charged, but residual imbalance remains high, which suggests stronger balancing or longer top-of-charge time may be needed.";
else
    text = "The result is usable for analysis, but the charging trajectory should be reviewed because the final state is not yet fully ideal.";
end
end

function realismText = assess_realism(metrics, cfg)
hasCvStage = ~isnan(metrics.charging.cvDuration_s) && metrics.charging.cvDuration_s > 0;
hasResidualImbalance = ~isnan(metrics.balancing.finalImbalance_V) ...
    && metrics.balancing.finalImbalance_V >= 0.005 ...
    && metrics.balancing.finalImbalance_V <= 0.020;
hasVisibleThermalRise = ~isnan(metrics.temperature.maxRiseAboveAmbient_C) && metrics.temperature.maxRiseAboveAmbient_C >= 1.0;
hasNonIdealFinalSoc = ~isnan(metrics.performance.finalSoCSpread_percent) && metrics.performance.finalSoCSpread_percent > 0;

if hasCvStage && hasResidualImbalance && hasVisibleThermalRise && hasNonIdealFinalSoc
    realismText = "Realistic";
elseif hasCvStage || hasVisibleThermalRise
    realismText = "Moderately realistic";
else
    realismText = "Still somewhat idealized";
end
end

function overall = determine_overall_result(metrics)
if metrics.validation.hasWarning && ...
        (metrics.safety.overvoltageDetected || metrics.safety.overtemperatureDetected || metrics.soc.driftDetected)
    overall = "FAIL";
elseif metrics.validation.hasWarning
    overall = "WARNING";
else
    overall = "PASS";
end
end

function success = compute_success_flag(metrics, cfg)
success = metrics.charging.finalAverageSoC >= 0.98 ...
    && metrics.balancing.finalImbalance_V <= max(cfg.balance.deltaTrigger_V, 0.02) ...
    && ~metrics.safety.overvoltageDetected ...
    && ~metrics.safety.overtemperatureDetected;
end

function efficiency_percent = compute_efficiency(results, cfg, dt_s)
packVoltage_V = force_column(get_optional_signal(results, "packVoltage_V"));
chargeCurrent_A = force_column(get_optional_signal(results, "chargeCurrent_A"));
soc = force_matrix(get_optional_signal(results, "soc"), cfg.pack.numCells);

if isempty(packVoltage_V) || isempty(chargeCurrent_A) || isempty(soc)
    efficiency_percent = NaN;
    return;
end

inputEnergy_J = sum(max(chargeCurrent_A, 0) .* max(packVoltage_V, 0)) * dt_s;
deltaSoc = max(0, mean(soc(end, :)) - mean(cfg.init.soc));
storedEnergy_J = deltaSoc * cfg.pack.capacity_As * cfg.pack.nominalPackVoltage_V;

if inputEnergy_J <= 0
    efficiency_percent = NaN;
else
    efficiency_percent = 100 * storedEnergy_J / inputEnergy_J;
end
end

function stopReason = determine_stop_reason(metrics, chargerMode, chargeCurrent_A, soc, cfg, terminationReasonSignal)
if ~isempty(terminationReasonSignal)
    lastReason = terminationReasonSignal(end);
    if strlength(lastReason) > 0 && lastReason ~= "Running"
        stopReason = lastReason;
        return;
    end
end

if metrics.safety.overtemperatureDetected
    stopReason = "Stopped due to overtemperature condition.";
elseif metrics.safety.overvoltageDetected
    stopReason = "Stopped due to cell overvoltage condition.";
elseif any(chargerMode == "DONE")
    stopReason = "Charging completed in normal CC-CV operation.";
elseif ~isempty(chargeCurrent_A) && safe_last(chargeCurrent_A) <= cfg.charge.minTerminationCurrent_A ...
        && ~isempty(soc) && mean(soc(end, :)) >= 0.99
    stopReason = "Charging tapered to termination current near full SoC.";
else
    stopReason = "Not available in current model";
end
end

function decayObserved = detect_cv_current_decay(chargerMode, chargeCurrent_A)
if isempty(chargerMode) || isempty(chargeCurrent_A)
    decayObserved = NaN;
    return;
end

cvIdx = find(chargerMode == "CV");
if numel(cvIdx) < 3
    decayObserved = false;
    return;
end

cvCurrent = chargeCurrent_A(cvIdx);
decayObserved = cvCurrent(end) < cvCurrent(1) && min(diff(cvCurrent)) <= 0;
end

function t = compute_first_threshold_time(time_s, signal, threshold)
if isempty(time_s) || isempty(signal)
    t = NaN;
    return;
end

idx = find(signal >= threshold, 1, "first");
if isempty(idx)
    t = NaN;
else
    t = time_s(idx);
end
end

function flag = detect_overtemperature(temperature_C, cfg)
flag = any_numeric_signal_exceeds(temperature_C, cfg.safety.maxTemperature_C);
end

function flag = detect_thermal_warning(temperature_C, cfg)
flag = any_numeric_signal_exceeds(temperature_C, cfg.safety.derateTemperature_C);
end

function energy_J = compute_balance_energy(bleedCurrent_A, resistor_Ohm, dt_s)
if isempty(bleedCurrent_A)
    energy_J = NaN;
else
    energy_J = sum((bleedCurrent_A(:) .^ 2) * resistor_Ohm) * dt_s;
end
end

function energyPerCell_J = compute_balance_energy_per_cell(bleedCurrent_A, resistor_Ohm, dt_s)
if isempty(bleedCurrent_A)
    energyPerCell_J = NaN;
else
    energyPerCell_J = sum((bleedCurrent_A .^ 2) * resistor_Ohm, 1) * dt_s;
end
end

function imbalance_V = compute_pre_balance_imbalance(cellVoltage_V, balanceSignal)
if isempty(cellVoltage_V)
    imbalance_V = NaN;
    return;
end

if isempty(balanceSignal) || ~any(balanceSignal(:) > 0.5)
    imbalance_V = max(max(cellVoltage_V, [], 2) - min(cellVoltage_V, [], 2));
    return;
end

firstBalanceIdx = find(any(balanceSignal > 0.5, 2), 1, "first");
if isempty(firstBalanceIdx)
    imbalance_V = max(max(cellVoltage_V, [], 2) - min(cellVoltage_V, [], 2));
else
    imbalance_V = compute_window_imbalance(cellVoltage_V, 1, max(firstBalanceIdx, 1));
end
end

function imbalance_V = compute_window_imbalance(cellVoltage_V, startIdx, endIdx)
if isempty(cellVoltage_V)
    imbalance_V = NaN;
    return;
end

startIdx = max(1, startIdx);
endIdx = min(size(cellVoltage_V, 1), endIdx);
window = cellVoltage_V(startIdx:endIdx, :);
imbalance_V = max(max(window, [], 2) - min(window, [], 2));
end

function spread_V = compute_final_spread(cellVoltage_V)
lastRow = safe_last_row(cellVoltage_V);
spread_V = compute_spread(lastRow);
end

function spread = compute_spread(values)
if isempty(values) || any(isnan(values))
    spread = NaN;
else
    spread = max(values) - min(values);
end
end

function flag = all_in_range(values, lowerLimit, upperLimit)
if isempty(values) || any(isnan(values))
    flag = false;
else
    flag = all(values >= lowerLimit) && all(values <= upperLimit);
end
end

function value = get_optional_signal(results, fieldName)
if isfield(results, fieldName)
    value = results.(fieldName);
else
    value = [];
end
end

function versionText = get_simulink_version_safe()
try
    versionText = string(ver("simulink").Version);
catch
    versionText = "Not available in current model";
end
end

function dt_s = infer_sample_time(time_s, fallbackValue)
if numel(time_s) >= 2
    diffs = diff(time_s);
    dt_s = median(diffs(~isnan(diffs) & ~isinf(diffs)));
    if isempty(dt_s)
        dt_s = fallbackValue;
    end
else
    dt_s = fallbackValue;
end
end

function write_text_file(filePath, textContent)
fileId = fopen(filePath, "w");
if fileId < 0
    error("Unable to write report file: %s", filePath);
end
cleanupObj = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, "%s", textContent);
end

function write_summary_metrics_csv(filePath, metrics)
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
    safe_max(metrics.temperature.maxTemperaturePerCell_C)
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

T = table(metricName, value, unit);
writetable(T, filePath);
end

function write_time_series_csv(filePath, results)
time_s = force_column(get_optional_signal(results, "time_s"));

if isempty(time_s)
    T = table();
    writetable(T, filePath);
    return;
end

T = table(time_s, 'VariableNames', {'time_s'});
T = append_matrix_to_table(T, get_optional_signal(results, "cellVoltage_V"), "cellVoltage");
T = append_vector_to_table(T, get_optional_signal(results, "packVoltage_V"), "packVoltage_V");
T = append_vector_to_table(T, get_optional_signal(results, "chargeCurrent_A"), "chargeCurrent_A");
T = append_matrix_to_table(T, get_optional_signal(results, "soc"), "soc");
T = append_matrix_to_table(T, get_optional_signal(results, "temperature_C"), "temperature");
T = append_matrix_to_table(T, double(get_optional_signal(results, "balanceSignal")), "balanceSignal");
T = append_matrix_to_table(T, get_optional_signal(results, "bleedCurrent_A"), "bleedCurrent");

if isfield(results, "chargerMode")
    modeSignal = normalize_string_signal(results.chargerMode);
    T.chargerMode = string(modeSignal(:));
end

writetable(T, filePath);
end

function T = append_vector_to_table(T, values, variableName)
values = force_column(values);
if isempty(values) || height(T) ~= numel(values)
    return;
end
T.(variableName) = values;
end

function T = append_matrix_to_table(T, values, prefix)
if isempty(values)
    return;
end

if isvector(values)
    values = values(:);
end

if size(values, 1) ~= height(T)
    return;
end

for idx = 1:size(values, 2)
    T.(sprintf("%s_%d", prefix, idx)) = values(:, idx);
end
end

function signal = normalize_string_signal(signal)
if isempty(signal)
    signal = strings(0, 1);
elseif isstring(signal)
    signal = signal(:);
elseif ischar(signal)
    signal = string(cellstr(signal));
elseif iscellstr(signal)
    signal = string(signal(:));
else
    signal = strings(0, 1);
end
end

function column = force_column(values)
if isempty(values)
    column = [];
else
    column = values(:);
end
end

function matrix = force_matrix(values, numCols)
if isempty(values)
    matrix = [];
    return;
end

if isvector(values) && nargin > 1 && numCols > 1
    if mod(numel(values), numCols) == 0
        matrix = reshape(values, [], numCols);
    else
        matrix = values(:);
    end
else
    matrix = values;
end
end

function value = safe_last(signal)
if isempty(signal)
    value = NaN;
else
    value = signal(end);
end
end

function value = safe_first(signal)
if isempty(signal)
    value = NaN;
else
    value = signal(1);
end
end

function row = safe_last_row(signal)
if isempty(signal)
    row = NaN;
elseif isvector(signal)
    row = signal(end);
else
    row = signal(end, :);
end
end

function value = safe_mean(signal)
if isempty(signal)
    value = NaN;
else
    value = mean(signal, "all", "omitnan");
end
end

function value = safe_max(signal)
if isempty(signal)
    value = NaN;
else
    value = max(signal, [], "all");
end
end

function value = safe_min(signal)
if isempty(signal)
    value = NaN;
else
    value = min(signal, [], "all");
end
end

function values = safe_max_rowwise(signal)
if isempty(signal)
    values = NaN;
elseif isvector(signal)
    values = max(signal);
else
    values = max(signal, [], 1);
end
end

function values = max_by_row(signal)
if isempty(signal)
    values = [];
else
    values = max(signal, [], 2);
end
end

function flag = any_numeric_signal_exceeds(signal, threshold)
flag = ~isempty(signal) && any(signal(:) > threshold);
end

function flag = any_numeric_signal_below(signal, threshold)
flag = ~isempty(signal) && any(signal(:) < threshold);
end

function line = format_line(label, value)
line = string(label) + ": " + scalarize_string(value);
end

function lines = append_lines(lines, newLines)
if isempty(newLines)
    return;
end

lines = string(lines);
lines = lines(:);
newLines = string(newLines(:));
lines = [lines; newLines];
end

function value = scalarize_string(value)
value = string(value);
value = value(:);
if isempty(value)
    value = "Not available in current model";
else
    value = strjoin(value, " ");
end
end

function value = format_scalar(numberValue, unit)
if isempty(numberValue) || any(isnan(numberValue))
    value = "Not available in current model";
elseif strlength(string(unit)) == 0
    value = sprintf("%.4f", numberValue);
else
    value = sprintf("%.4f %s", numberValue, unit);
end
end

function value = format_vector(values, unit)
if isempty(values) || any(isnan(values))
    value = "Not available in current model";
    return;
end

values = values(:).';

if strcmp(unit, "%")
    value = "[" + strjoin(compose("%.2f %%", 100 * values), ", ") + "]";
else
    formattedValues = compose("%.4f", values);
    if strlength(string(unit)) > 0
        formattedValues = formattedValues + " " + string(unit);
    end
    value = "[" + strjoin(formattedValues, ", ") + "]";
end
end

function value = format_vector_seconds(values)
if isempty(values) || any(isnan(values))
    value = "Not available in current model";
else
    values = values(:).';
    value = "[" + strjoin(compose("%.1f s", values), ", ") + "]";
end
end

function value = format_index_vector(values)
if isempty(values)
    value = "None";
else
    value = "[" + strjoin(string(values), ", ") + "]";
end
end

function value = format_duration(time_s)
if isempty(time_s) || isnan(time_s)
    value = "Not available in current model";
else
    value = sprintf("%.1f s (%.2f min, %.2f h)", time_s, time_s / 60, time_s / 3600);
end
end

function value = yes_no(flag)
if isempty(flag) || any(isnan(flag))
    value = "Not available in current model";
elseif flag
    value = "Yes";
else
    value = "No";
end
end
