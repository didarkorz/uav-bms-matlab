%% run_bms_simulink_simulation.m
% Build and simulate the full Simulink BMS project, then reuse the MATLAB
% plotting workflow so thesis figures stay consistent across both paths.

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
run(fullfile(projectRoot, "config", "init_bms_project.m"));

modelName = build_bms_simulink_model();
simOut = sim(modelName);

results.time_s = safe_logged_signal_time(simOut, "cellVoltagesSim");
results.cellVoltage_V = safe_logged_signal_values(simOut, "cellVoltagesSim");
results.packVoltage_V = safe_logged_signal_values(simOut, "packVoltageSim");
results.chargeCurrent_A = safe_logged_signal_values(simOut, "chargeCurrentSim");
results.soc = safe_logged_signal_values(simOut, "socEstimateSim");
results.temperature_C = safe_logged_signal_values(simOut, "temperatureSim");
results.balanceSignal = logical(round(safe_logged_signal_values(simOut, "balanceSignalSim")));
results.bleedCurrent_A = safe_logged_signal_values(simOut, "bleedCurrentSim");
results.ocv_V = results.cellVoltage_V;
results.chargerMode = strings(numel(results.time_s), 1);
results.protectionActive = ~logical(round(safe_logged_signal_values(simOut, "protectionFlagSim")));
if isempty(results.protectionActive)
    results.protectionActive = false(max(numel(results.time_s), 1), 1);
end

if ~isempty(results.time_s) && ~isempty(results.cellVoltage_V) && ~isempty(results.packVoltage_V)
    plot_bms_results(results, cfg);
else
    disp("Plot generation skipped because one or more logged signals are not available in the current Simulink model.");
end

reportOptions.projectRoot = projectRoot;
reportOptions.outputFolder = fullfile(projectRoot, cfg.output.resultsFolder);
reportOptions.modelName = modelName;
reportOptions.simulationType = "Simulink";
reportOptions.solver = string(get_param(modelName, "Solver"));
reportOptions.sampleTime_s = str2double(get_param(modelName, "FixedStep"));
reportOptions.notes = "Signals missing from workspace logs are reported as not available.";
if exist("simOut", "var")
    reportOptions.notes = reportOptions.notes + " SimOut object created successfully.";
end

report = generate_simulation_report(results, cfg, reportOptions); %#ok<NASGU>

disp("Simulink simulation completed and plots generated.");
disp("Exported report files:");
disp(report.exportPaths);

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

function timeVector = safe_logged_signal_time(simOut, variableName)
signalStruct = get_logged_signal_struct(simOut, variableName);
if ~isempty(signalStruct)
    if isstruct(signalStruct) && isfield(signalStruct, "time")
        timeVector = signalStruct.time(:);
    else
        timeVector = [];
    end
else
    timeVector = [];
end
end

function values = safe_logged_signal_values(simOut, variableName)
signalStruct = get_logged_signal_struct(simOut, variableName);
if ~isempty(signalStruct)
    if isstruct(signalStruct) && isfield(signalStruct, "signals") && isfield(signalStruct.signals, "values")
        values = signalStruct.signals.values;
        if ndims(values) == 3
            values = squeeze(values);
        end
        if isvector(values)
            values = values(:);
        end
    else
        values = [];
    end
else
    values = [];
end
end

function signalStruct = get_logged_signal_struct(simOut, variableName)
signalStruct = [];

if nargin >= 1 && ~isempty(simOut)
    try
        signalStruct = simOut.get(variableName);
    catch
        signalStruct = [];
    end
end

if isempty(signalStruct) && evalin("base", "exist('" + variableName + "', 'var')")
    signalStruct = evalin("base", variableName);
end
end
