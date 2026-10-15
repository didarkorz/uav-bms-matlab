%% 05_build_ocv_soc_table.m
% Combine Oxford and CALCE data into an OCV-SOC lookup table.

cfg = bms_load_cfg();

if ~exist(cfg.files.oxford, "file")
    run(fullfile(cfg.paths.scripts, "step02_import_oxford.m"));
end
if ~exist(cfg.files.calce, "file")
    run(fullfile(cfg.paths.scripts, "step03_import_calce.m"));
end

oxfordOcvProfiles = table();
calceOcvProfiles = table();

if exist(cfg.files.oxford, "file")
    S = load(cfg.files.oxford);
    if isfield(S, "oxfordOcvProfiles")
        oxfordOcvProfiles = S.oxfordOcvProfiles;
    end
    if isempty(oxfordOcvProfiles) && isfield(S, "oxfordTable")
        oxfordOcvProfiles = local_profiles_from_standardized_table(S.oxfordTable, "Oxford");
    end
end
if exist(cfg.files.calce, "file")
    S = load(cfg.files.calce);
    if isfield(S, "calceOcvProfiles")
        calceOcvProfiles = S.calceOcvProfiles;
    end
    if isempty(calceOcvProfiles) && isfield(S, "calceTable")
        calceOcvProfiles = local_profiles_from_standardized_table(S.calceTable, "CALCE");
    end
end

lookup = bms_build_ocv_lookup(oxfordOcvProfiles, calceOcvProfiles, cfg);
save(cfg.files.ocvLookup, "lookup");
writetable(lookup.table, fullfile(cfg.paths.results, "ocv_soc_table.csv"));

fprintf("Saved OCV-SOC lookup table to %s\n", fullfile(cfg.paths.results, "ocv_soc_table.csv"));
fprintf("Temperatures represented: %s\n", mat2str(lookup.temperature_grid_C));

function profiles = local_profiles_from_standardized_table(T, datasetName)
profiles = table();
if isempty(T) || ~all(ismember(["cell_id", "cycle_id", "capacity_Ah", "voltage_V"], T.Properties.VariableNames))
    return;
end

[groupIds, cellVals, cycleVals] = findgroups(T.cell_id, T.cycle_id);
for groupIdx = 1:max(groupIds)
    part = T(groupIds == groupIdx, :);
    if height(part) < 10 || all(isnan(part.capacity_Ah)) || all(isnan(part.voltage_V))
        continue;
    end
    q = part.capacity_Ah - min(part.capacity_Ah);
    if max(q) <= 0
        continue;
    end
    soc = q ./ max(q);
    if part.voltage_V(end) < part.voltage_V(1)
        soc = 1 - soc;
    end
    [socUnique, ia] = unique(soc);
    if numel(socUnique) < 10
        continue;
    end
    socUnique = socUnique(:);
    ocvVec = part.voltage_V(ia);
    ocvVec = ocvVec(:);
    tempVec = repmat(mean(part.temp_C, "omitnan"), numel(socUnique), 1);
    datasetVec = repmat(string(datasetName), numel(socUnique), 1);
    sourceVec = repmat(string(cellVals(groupIdx)) + "_" + string(cycleVals(groupIdx)), numel(socUnique), 1);
    profiles = [profiles; table( ...
        socUnique, ocvVec, tempVec, datasetVec, sourceVec, ...
        'VariableNames', {'soc', 'ocv_V', 'temp_C', 'dataset_id', 'source_id'})]; %#ok<AGROW>
end
end
