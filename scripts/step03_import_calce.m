%% 03_import_calce.m
% Import CALCE OCV-SOC data if available, otherwise create a placeholder.

cfg = bms_load_cfg();
files = bms_find_dataset_files(cfg.paths.search.calce, {"*.csv", "*.mat"});

calceTable = table();
calceOcvProfiles = table();

if isempty(files)
    fprintf("Dataset file not found. Place file in /data/raw/calce\n");
    save(cfg.files.calce, "calceTable", "calceOcvProfiles");
    return;
end

for idx = 1:numel(files)
    fullPath = fullfile(files(idx).folder, files(idx).name);
    [~, stem, ext] = fileparts(fullPath);
    try
        switch lower(ext)
            case ".csv"
                raw = readtable(fullPath);
                vars = lower(string(raw.Properties.VariableNames));
                soc = local_pick_column(raw, vars, ["soc", "state_of_charge"]);
                ocv_V = local_pick_column(raw, vars, ["ocv", "voltage", "ocv_v"]);
                temp_C = local_pick_column(raw, vars, ["temp", "temperature", "temp_c"]);

                if isempty(soc)
                    capacity_Ah = local_pick_column(raw, vars, ["capacity_ah", "charge_ah", "q"]);
                    if ~isempty(capacity_Ah)
                        capacity_Ah = capacity_Ah - min(capacity_Ah);
                        soc = capacity_Ah ./ max(capacity_Ah);
                    end
                end

                if isempty(temp_C)
                    temp_C = repmat(cfg.processing.defaultOcvTemperature_C, height(raw), 1);
                end

                if ~isempty(soc) && ~isempty(ocv_V)
                    calceOcvProfiles = [calceOcvProfiles; table( ...
                        double(soc(:)), double(ocv_V(:)), double(temp_C(:)), ...
                        repmat("CALCE", numel(soc), 1), repmat(string(stem), numel(soc), 1), ...
                        "VariableNames", {"soc", "ocv_V", "temp_C", "dataset_id", "source_id"})]; %#ok<AGROW>
                end

            case ".mat"
                loaded = load(fullPath);
                records = bms_extract_mat_records(loaded, stem);
                part = bms_records_to_table(records, "CALCE", fullPath);
                if ~isempty(part)
                    calceTable = [calceTable; part(:, 1:8)]; %#ok<AGROW>
                    calceOcvProfiles = [calceOcvProfiles; local_profiles_from_table(part, stem)]; %#ok<AGROW>
                end
        end
    catch ME
        fprintf("CALCE import warning for %s: %s\n", fullPath, ME.message);
    end
end

save(cfg.files.calce, "calceTable", "calceOcvProfiles");
if ~isempty(calceTable)
    writetable(calceTable, fullfile(cfg.paths.processed, "calce_standardized.csv"));
end
if ~isempty(calceOcvProfiles)
    writetable(calceOcvProfiles, fullfile(cfg.paths.processed, "calce_ocv_profiles.csv"));
end

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

function profiles = local_profiles_from_table(T, stem)
profiles = table();
if isempty(T) || all(isnan(T.capacity_Ah))
    return;
end
q = T.capacity_Ah - min(T.capacity_Ah);
if max(q) <= 0
    return;
end
soc = q ./ max(q);
profiles = table(double(soc(:)), double(T.voltage_V(:)), double(T.temp_C(:)), ...
    repmat("CALCE", height(T), 1), repmat(string(stem), height(T), 1), ...
    "VariableNames", {"soc", "ocv_V", "temp_C", "dataset_id", "source_id"});
end
