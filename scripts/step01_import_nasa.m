%% 01_import_nasa.m
% Import NASA battery files into the common table format.

cfg = bms_load_cfg();
files = bms_find_dataset_files(cfg.paths.search.nasa, {"*.mat", "*.csv"});

if isempty(files)
    fprintf("Dataset file not found. Place file in /data/raw/nasa\n");
    nasaTable = bms_standardize_timeseries([], [], [], [], [], "NASA", "missing", "missing");
    save(cfg.files.nasa, "nasaTable", "-v7.3");
    writetable(nasaTable, fullfile(cfg.paths.processed, "nasa_standardized.csv"));
    return;
end

nasaTable = table();

for idx = 1:numel(files)
    fullPath = fullfile(files(idx).folder, files(idx).name);
    [~, fileStem, fileExt] = fileparts(fullPath);

    try
        switch lower(fileExt)
            case ".csv"
                raw = readtable(fullPath);
                vars = lower(string(raw.Properties.VariableNames));

                time_s = local_as_numeric(local_pick_column(raw, vars, ["time", "time_s"]));
                voltage_V = local_as_numeric(local_pick_column(raw, vars, ["voltage", "voltage_charger", "voltage_load"]));
                current_A = local_as_numeric(local_pick_column(raw, vars, ["current", "current_a", "current_load"]));
                temp_C = local_as_numeric(local_pick_column(raw, vars, ["temp", "temperature", "temperature_battery"]));
                capacity_Ah = local_as_numeric(local_pick_column(raw, vars, ["capacity_ah", "capacity"]));

                if isempty(time_s)
                    time_s = (0:height(raw) - 1).';
                end
                if isempty(voltage_V)
                    voltage_V = NaN(height(raw), 1);
                end
                if isempty(current_A)
                    current_A = zeros(height(raw), 1);
                else
                    current_A = -double(current_A(:));
                end
                if isempty(temp_C)
                    temp_C = NaN(height(raw), 1);
                end
                if isempty(capacity_Ah)
                    capacity_Ah = cumtrapz(double(time_s(:)), abs(double(current_A(:)))) ./ 3600;
                end

                [time_s, voltage_V, current_A, temp_C, capacity_Ah] = local_limit_rows( ...
                    time_s, voltage_V, current_A, temp_C, capacity_Ah, cfg.processing.maxRowsPerFile);
                part = bms_standardize_timeseries(time_s, voltage_V, current_A, temp_C, capacity_Ah, "NASA", fileStem, "cycle_001");
                nasaTable = [nasaTable; part]; %#ok<AGROW>

            case ".mat"
                loaded = load(fullPath);
                records = bms_extract_mat_records(loaded, fileStem);
                part = bms_records_to_table(records, "NASA", fullPath);
                if ~isempty(part)
                    part = part(:, 1:8);
                    if height(part) > cfg.processing.maxRowsPerFile
                        keepIdx = round(linspace(1, height(part), cfg.processing.maxRowsPerFile));
                        part = part(keepIdx, :);
                    end
                    nasaTable = [nasaTable; part]; %#ok<AGROW>
                end
        end
    catch ME
        fprintf("NASA import warning for %s: %s\n", fullPath, ME.message);
    end
end

if isempty(nasaTable)
    fprintf("Dataset file not found. Place file in /data/raw/nasa\n");
    nasaTable = bms_standardize_timeseries([], [], [], [], [], "NASA", "missing", "missing");
end

save(cfg.files.nasa, "nasaTable", "-v7.3");
writetable(nasaTable, fullfile(cfg.paths.processed, "nasa_standardized.csv"));
fprintf("Saved NASA standardized table with %d rows.\n", height(nasaTable));

function values = local_pick_column(T, varNames, candidates)
values = [];
for idx = 1:numel(candidates)
    match = find(varNames == lower(string(candidates(idx))), 1, "first");
    if ~isempty(match)
        values = T{:, match};
        return;
    end
end
end

function values = local_as_numeric(values)
if isempty(values)
    return;
end
if isnumeric(values)
    values = double(values(:));
    return;
end
if iscell(values)
    values = string(values);
end
if isstring(values) || ischar(values)
    values = str2double(string(values(:)));
    return;
end
try
    values = double(values(:));
catch
    values = [];
end
end

function [time_s, voltage_V, current_A, temp_C, capacity_Ah] = local_limit_rows(time_s, voltage_V, current_A, temp_C, capacity_Ah, maxRows)
n = numel(time_s);
if n <= maxRows
    return;
end
keepIdx = unique(round(linspace(1, n, maxRows)));
time_s = time_s(keepIdx);
voltage_V = voltage_V(keepIdx);
current_A = current_A(keepIdx);
temp_C = temp_C(keepIdx);
capacity_Ah = capacity_Ah(keepIdx);
end
