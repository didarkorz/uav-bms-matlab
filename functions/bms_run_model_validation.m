function [validationMetrics, validationSeries] = bms_run_model_validation(cfg)
%BMS_RUN_MODEL_VALIDATION Validate the single-cell ECM against measured data.

if ~exist(cfg.files.oxford, "file")
    run(fullfile(cfg.paths.scripts, "step02_import_oxford.m"));
end
if ~exist(cfg.files.nasa, "file")
    run(fullfile(cfg.paths.scripts, "step01_import_nasa.m"));
end
if ~exist(cfg.files.ocvLookup, "file")
    run(fullfile(cfg.paths.scripts, "step05_build_ocv_soc_table.m"));
end
if ~exist(cfg.files.cellParameters, "file")
    run(fullfile(cfg.paths.scripts, "step06_estimate_cell_parameters.m"));
end

lookupData = load(cfg.files.ocvLookup, "lookup");
parameterData = load(cfg.files.cellParameters, "estimates");

[profileTable, selectionInfo] = local_select_validation_profile(cfg);
if isempty(profileTable)
    error("No suitable measured profile was found for model validation.");
end

validationSeries = local_simulate_profile(profileTable, lookupData.lookup, parameterData.estimates, cfg, selectionInfo);
validationMetrics = local_compute_metrics(validationSeries, selectionInfo);
end

function [profileTable, selectionInfo] = local_select_validation_profile(cfg)
profileTable = table();
selectionInfo = struct("dataset_id", "", "cell_id", "", "cycle_id", "", "profile_note", "");

if exist(cfg.files.oxford, "file")
    S = load(cfg.files.oxford);
    if isfield(S, "oxfordTable") && ~isempty(S.oxfordTable)
        [profileTable, selectionInfo] = local_pick_profile(S.oxfordTable, "Oxford", cfg);
        if ~isempty(profileTable)
            return;
        end
    end
end

if exist(cfg.files.nasa, "file")
    S = load(cfg.files.nasa);
    if isfield(S, "nasaTable") && ~isempty(S.nasaTable)
        [profileTable, selectionInfo] = local_pick_profile(S.nasaTable, "NASA", cfg);
    end
end
end

function [profileTable, selectionInfo] = local_pick_profile(T, preferredDataset, cfg)
profileTable = table();
selectionInfo = struct("dataset_id", preferredDataset, "cell_id", "", "cycle_id", "", "profile_note", "");

requiredVars = {'time_s', 'voltage_V', 'current_A', 'temp_C', 'capacity_Ah', 'dataset_id', 'cell_id', 'cycle_id'};
if ~all(ismember(requiredVars, T.Properties.VariableNames))
    return;
end

if ~ismember("soc_est", T.Properties.VariableNames)
    T.soc_est = NaN(height(T), 1);
end

datasetMask = strcmpi(cellstr(T.dataset_id), preferredDataset);
T = T(datasetMask, :);
if isempty(T)
    return;
end

groupId = findgroups(T.cell_id, T.cycle_id);
bestScore = -inf;
bestIdx = 0;
for idx = 1:max(groupId)
    part = T(groupId == idx, :);
    valid = isfinite(part.time_s) & isfinite(part.voltage_V);
    if sum(valid) < 25
        continue;
    end
    part = part(valid, :);
    currentValid = part.current_A(isfinite(part.current_A));
    if isempty(currentValid)
        continue;
    end
    voltageSpan = max(part.voltage_V) - min(part.voltage_V);
    currentSpan = max(currentValid) - min(currentValid);
    stageBonus = 0;
    cycleName = lower(string(part.cycle_id(1)));
    if contains(cycleName, "c1ch") || contains(cycleName, "_ch")
        stageBonus = stageBonus + 20;
    elseif contains(cycleName, "c1dc") || contains(cycleName, "_dc")
        stageBonus = stageBonus + 10;
    end
    if preferredDataset == "Oxford"
        stageBonus = stageBonus + 30;
    end
    score = height(part) + 50 * voltageSpan + 10 * currentSpan + stageBonus;
    if score > bestScore
        bestScore = score;
        bestIdx = idx;
    end
end

if bestIdx == 0
    return;
end

profileTable = T(groupId == bestIdx, :);
profileTable = sortrows(profileTable, 'time_s');
profileTable = profileTable(isfinite(profileTable.time_s) & isfinite(profileTable.voltage_V), :);
if height(profileTable) > cfg.processing.maxValidationRows
    keepIdx = unique(round(linspace(1, height(profileTable), cfg.processing.maxValidationRows)));
    profileTable = profileTable(keepIdx, :);
end

selectionInfo.cell_id = string(profileTable.cell_id(1));
selectionInfo.cycle_id = string(profileTable.cycle_id(1));
selectionInfo.profile_note = "Measured current profile replayed through the single-cell ECM.";
end

function validationSeries = local_simulate_profile(profileTable, lookup, estimates, cfg, selectionInfo)
time_s = profileTable.time_s(:);
time_s = time_s - time_s(1);
current_A = profileTable.current_A(:);
measured_V = profileTable.voltage_V(:);

temp_C = profileTable.temp_C(:);
invalidTemp = ~isfinite(temp_C) | abs(temp_C) > 100;
temp_C(invalidTemp) = cfg.thermal.ambient_C;

capacity_Ah = profileTable.capacity_Ah(:);
if ismember("soc_est", profileTable.Properties.VariableNames)
    soc_est = profileTable.soc_est(:);
else
    soc_est = NaN(size(capacity_Ah));
end

validCapacity = capacity_Ah(isfinite(capacity_Ah));
if numel(validCapacity) > 2
    qnUsed_Ah = max(validCapacity) - min(validCapacity);
else
    qnUsed_Ah = estimates.Qn_est_Ah;
end
if ~isfinite(qnUsed_Ah) || qnUsed_Ah <= 0.05
    qnUsed_Ah = max(0.5, mean(cfg.cells.capacity_Ah));
end

soc0 = NaN;
if any(isfinite(soc_est))
    firstIdx = find(isfinite(soc_est), 1, 'first');
    soc0 = soc_est(firstIdx);
end
if ~isfinite(soc0)
    soc0 = bms_soc_from_ocv(lookup, measured_V(1), temp_C(1));
end
soc0 = max(min(double(soc0), 1), 0);

R0_candidates = [];
if numel(current_A) > 1
    dI = diff(current_A);
    dV = diff(measured_V);
    mask = abs(dI) > max(0.05, 0.05 * max(abs(current_A), [], 'omitnan'));
    if any(mask)
        R0_candidates = abs(dV(mask) ./ dI(mask));
        R0_candidates = R0_candidates(isfinite(R0_candidates) & R0_candidates > 0);
    end
end
if isempty(R0_candidates)
    R0_used_Ohm = mean(cfg.cells.R0_Ohm);
else
    R0_used_Ohm = min(max(median(R0_candidates), 0.005), 0.08);
end

R1_used_Ohm = max(0.002, min(0.03, mean(cfg.cells.R1_Ohm) * max(qnUsed_Ah / mean(cfg.cells.capacity_Ah), 0.2)));
C1_used_F = max(200, mean(cfg.cells.C1_F) * max(qnUsed_Ah / mean(cfg.cells.capacity_Ah), 0.2));

n = numel(time_s);
soc = zeros(n, 1);
simulated_V = zeros(n, 1);
vrc = zeros(n, 1);
soc(1) = soc0;
ocv0 = bms_ocv_from_lookup(lookup, soc0, temp_C(1));
vrc(1) = measured_V(1) - ocv0 - current_A(1) * R0_used_Ohm;
simulated_V(1) = measured_V(1);

for k = 1:n - 1
    dt = time_s(k + 1) - time_s(k);
    if ~isfinite(dt) || dt <= 0
        dt = cfg.sim.dt_s;
    end

    soc(k + 1) = soc(k) + current_A(k) * dt / (3600 * qnUsed_Ah);
    soc(k + 1) = max(min(soc(k + 1), 1), 0);

    alpha = exp(-dt / max(R1_used_Ohm * C1_used_F, eps));
    vrc(k + 1) = alpha * vrc(k) + (1 - alpha) * R1_used_Ohm * current_A(k);
    ocvNow = bms_ocv_from_lookup(lookup, soc(k + 1), temp_C(k + 1));
    simulated_V(k + 1) = ocvNow + current_A(k + 1) * R0_used_Ohm + vrc(k + 1);
end

validationSeries = table( ...
    repmat(string(selectionInfo.dataset_id), n, 1), repmat(string(selectionInfo.cell_id), n, 1), repmat(string(selectionInfo.cycle_id), n, 1), ...
    time_s, current_A, temp_C, measured_V, simulated_V, soc, ...
    'VariableNames', {'dataset_id', 'cell_id', 'cycle_id', 'time_s', 'current_A', 'temp_C', 'measured_voltage_V', 'simulated_voltage_V', 'simulated_soc'});
validationSeries.Properties.UserData = struct( ...
    "qn_used_Ah", qnUsed_Ah, ...
    "R0_used_Ohm", R0_used_Ohm, ...
    "R1_used_Ohm", R1_used_Ohm, ...
    "C1_used_F", C1_used_F);
end

function validationMetrics = local_compute_metrics(validationSeries, selectionInfo)
err = validationSeries.simulated_voltage_V - validationSeries.measured_voltage_V;
rmse = sqrt(mean(err .^ 2, 'omitnan'));
mae = mean(abs(err), 'omitnan');
maxAbs = max(abs(err), [], 'omitnan');

y = validationSeries.measured_voltage_V;
yHat = validationSeries.simulated_voltage_V;
if sum(isfinite(y)) > 2 && var(y, 'omitnan') > eps
    ssRes = sum((y - yHat) .^ 2, 'omitnan');
    ssTot = sum((y - mean(y, 'omitnan')) .^ 2, 'omitnan');
    r2 = 1 - ssRes / max(ssTot, eps);
else
    r2 = NaN;
end

meta = validationSeries.Properties.UserData;
validationMetrics = table( ...
    string(selectionInfo.dataset_id), string(selectionInfo.cell_id), string(selectionInfo.cycle_id), ...
    height(validationSeries), rmse, mae, maxAbs, r2, ...
    meta.qn_used_Ah, meta.R0_used_Ohm, meta.R1_used_Ohm, meta.C1_used_F, string(selectionInfo.profile_note), ...
    'VariableNames', {'dataset_id', 'cell_id', 'cycle_id', 'num_points', 'rmse_voltage_V', 'mae_voltage_V', 'max_abs_error_V', 'r2_score', 'qn_used_Ah', 'R0_used_Ohm', 'R1_used_Ohm', 'C1_used_F', 'validation_note'});
end
