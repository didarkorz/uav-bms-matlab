%% 04_import_stanford.m
% Import Stanford/MATR summary and cycle data if local MAT files exist.

cfg = bms_load_cfg();
files = bms_find_dataset_files(cfg.paths.search.stanford, {"*batch*.mat", "*.mat"});

stanfordSummary = table();
stanfordTimeSeries = table();
stanfordVariation = table();

if isempty(files)
    fprintf("Dataset file not found. Place file in /data/raw/stanford\n");
    save(cfg.files.stanford, "stanfordSummary", "stanfordTimeSeries", "stanfordVariation");
    return;
end

for idx = 1:numel(files)
    fullPath = fullfile(files(idx).folder, files(idx).name);
    try
        loaded = load(fullPath);
        candidateNames = fieldnames(loaded);
        for nameIdx = 1:numel(candidateNames)
            dataBlock = loaded.(candidateNames{nameIdx});
            [summaryPart, seriesPart] = local_extract_stanford_block(dataBlock, string(candidateNames{nameIdx}));
            stanfordSummary = [stanfordSummary; summaryPart]; %#ok<AGROW>
            stanfordTimeSeries = [stanfordTimeSeries; seriesPart]; %#ok<AGROW>
        end
    catch ME
        fprintf("Stanford import warning for %s: %s\n", fullPath, ME.message);
    end
end

if ~isempty(stanfordSummary)
    stanfordVariation = table( ...
        mean(stanfordSummary.capacity_Ah, "omitnan"), std(stanfordSummary.capacity_Ah, "omitnan"), ...
        mean(stanfordSummary.internal_resistance_Ohm, "omitnan"), std(stanfordSummary.internal_resistance_Ohm, "omitnan"), ...
        mean(stanfordSummary.charge_time_s, "omitnan"), std(stanfordSummary.charge_time_s, "omitnan"), ...
        "VariableNames", { ...
        "capacity_mean_Ah", "capacity_std_Ah", ...
        "R0_mean_Ohm", "R0_std_Ohm", ...
        "charge_time_mean_s", "charge_time_std_s"});
end

save(cfg.files.stanford, "stanfordSummary", "stanfordTimeSeries", "stanfordVariation");
if ~isempty(stanfordSummary)
    writetable(stanfordSummary, fullfile(cfg.paths.processed, "stanford_summary.csv"));
end
if ~isempty(stanfordTimeSeries)
    writetable(stanfordTimeSeries, fullfile(cfg.paths.processed, "stanford_timeseries.csv"));
end

function [summaryTable, seriesTable] = local_extract_stanford_block(dataBlock, datasetName)
summaryTable = table();
seriesTable = table();

if ~isstruct(dataBlock)
    return;
end

if ~isscalar(dataBlock)
    for idx = 1:numel(dataBlock)
        [summaryPart, seriesPart] = local_extract_stanford_block(dataBlock(idx), datasetName + "_" + string(idx));
        summaryTable = [summaryTable; summaryPart]; %#ok<AGROW>
        seriesTable = [seriesTable; seriesPart]; %#ok<AGROW>
    end
    return;
end

if isfield(dataBlock, "summary")
    summary = dataBlock.summary;
    cycleVec = local_get_field(summary, {"cycle"});
    qDischarge = local_get_field(summary, {"QDischarge", "qdischarge"});
    ir = local_get_field(summary, {"IR", "ir"});
    chargeTime = local_get_field(summary, {"chargetime", "charge_time"});
    tAvg = local_get_field(summary, {"Tavg", "tavg"});
    tMax = local_get_field(summary, {"Tmax", "tmax"});

    n = max([numel(cycleVec), numel(qDischarge), numel(ir), numel(chargeTime), numel(tAvg), numel(tMax), 1]);
    summaryTable = table( ...
        repmat(string(datasetName), n, 1), ...
        repmat(local_string_value(dataBlock, {"barcode", "channel"}), n, 1), ...
        local_expand(cycleVec, n), local_expand(qDischarge, n), local_expand(ir, n), ...
        local_expand(chargeTime, n), local_expand(tAvg, n), local_expand(tMax, n), ...
        "VariableNames", {"dataset_id", "cell_id", "cycle_id", "capacity_Ah", "internal_resistance_Ohm", "charge_time_s", "temp_avg_C", "temp_max_C"});
end

if isfield(dataBlock, "cycles")
    cycles = dataBlock.cycles;
    for cycIdx = 1:min(numel(cycles), 5)
        cyc = cycles(cycIdx);
        time_s = local_get_field(cyc, {"t", "time"});
        voltage_V = local_get_field(cyc, {"V", "v", "voltage"});
        current_A = local_get_field(cyc, {"I", "i", "current"});
        temp_C = local_get_field(cyc, {"T", "temp", "temperature"});
        capacity_Ah = local_get_field(cyc, {"Qc", "Qd", "QCharge", "QDischarge"});

        if isempty(time_s) || isempty(voltage_V)
            continue;
        end

        seriesPart = bms_standardize_timeseries(time_s, voltage_V, current_A, temp_C, capacity_Ah, ...
            "Stanford", local_string_value(dataBlock, {"barcode", "channel"}), "cycle_" + string(cycIdx));
        seriesTable = [seriesTable; seriesPart]; %#ok<AGROW>
    end
end
end

function value = local_get_field(S, names)
value = [];
if ~isstruct(S)
    return;
end
fields = fieldnames(S);
for idx = 1:numel(names)
    match = strcmpi(fields, names{idx});
    if any(match)
        value = S.(fields{find(match, 1, "first")});
        return;
    end
end
end

function values = local_expand(x, n)
if isempty(x)
    values = NaN(n, 1);
else
    values = double(x(:));
    if numel(values) == 1 && n > 1
        values = repmat(values, n, 1);
    elseif numel(values) < n
        values(end + 1:n, 1) = values(end);
    else
        values = values(1:n);
    end
end
end

function value = local_string_value(S, names)
value = "stanford_cell";
for idx = 1:numel(names)
    candidate = local_get_field(S, names(idx));
    if ~isempty(candidate)
        value = string(candidate(1));
        return;
    end
end
end
