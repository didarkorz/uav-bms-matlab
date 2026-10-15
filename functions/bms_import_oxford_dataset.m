function [oxfordTable, oxfordOcvProfiles, importInfo] = bms_import_oxford_dataset(cfg)
%BMS_IMPORT_OXFORD_DATASET Oxford-specific loader for example and full files.

files = bms_find_dataset_files(cfg.paths.search.oxford, {"*.mat"});

oxfordTable = local_empty_oxford_table();
oxfordOcvProfiles = local_empty_ocv_table();
importInfo = struct();
importInfo.files_found = numel(files);
importInfo.rows_imported = 0;
importInfo.ocv_rows_imported = 0;
importInfo.warning_count = 0;
importInfo.processed_files = strings(0, 1);
importInfo.notes = strings(0, 1);

if isempty(files)
    fprintf("Dataset file not found. Place file in /data/raw/oxford\n");
    return;
end

for fileIdx = 1:numel(files)
    fullPath = fullfile(files(fileIdx).folder, files(fileIdx).name);
    [~, stem] = fileparts(fullPath);

    try
        if strcmpi(files(fileIdx).name, "ExampleDC_C1.mat")
            [tablePart, ocvPart, noteLines] = local_import_example_cycle(fullPath, stem, cfg);
        else
            [tablePart, ocvPart, noteLines] = local_import_characterization_file(fullPath, cfg);
        end

        oxfordTable = [oxfordTable; tablePart]; %#ok<AGROW>
        oxfordOcvProfiles = [oxfordOcvProfiles; ocvPart]; %#ok<AGROW>
        importInfo.processed_files(end + 1, 1) = string(files(fileIdx).name); %#ok<AGROW>
        if ~isempty(noteLines)
            importInfo.notes = [importInfo.notes; noteLines(:)]; %#ok<AGROW>
        end
    catch ME
        importInfo.warning_count = importInfo.warning_count + 1;
        warnMsg = "Oxford import warning for " + string(files(fileIdx).name) + ": " + string(ME.message);
        importInfo.notes(end + 1, 1) = warnMsg; %#ok<AGROW>
        fprintf("%s\n", warnMsg);
    end
end

if isempty(oxfordTable)
    fprintf("Dataset file not found. Place file in /data/raw/oxford\n");
else
    oxfordTable = sortrows(oxfordTable, {'cell_id', 'cycle_id', 'time_s'});
end

if isempty(oxfordOcvProfiles) && ~isempty(oxfordTable)
    oxfordOcvProfiles = local_profiles_from_table(oxfordTable);
end

oxfordOcvProfiles = local_filter_ocv_profiles(oxfordOcvProfiles);

importInfo.rows_imported = height(oxfordTable);
importInfo.ocv_rows_imported = height(oxfordOcvProfiles);
end

function [oxfordTable, ocvProfiles, noteLines] = local_import_example_cycle(fullPath, stem, cfg)
loaded = load(fullPath);
rootNames = fieldnames(loaded);
if isempty(rootNames)
    error("No top-level variables found.");
end

root = loaded.(rootNames{1});
if ~isstruct(root)
    error("Example file did not contain the expected struct.");
end

oxfordTable = local_empty_oxford_table();
ocvProfiles = local_empty_ocv_table();
noteLines = "Imported ExampleDC_C1.mat using dedicated Oxford example parser.";

stageNames = {'ch', 'dc'};
for idx = 1:numel(stageNames)
    stageName = stageNames{idx};
    if ~isfield(root, stageName)
        fprintf("Oxford import warning for %s: missing stage %s.\n", fullPath, stageName);
        continue;
    end

    cycleLabel = string(stem) + "_" + string(stageName);
    part = local_parse_stage(root.(stageName), stageName, "ExampleDC_C1", cycleLabel, cfg);
    if isempty(part)
        continue;
    end
    oxfordTable = [oxfordTable; part]; %#ok<AGROW>
end

if ~isempty(oxfordTable)
    ocvProfiles = local_profiles_from_table(oxfordTable);
end
end

function [oxfordTable, ocvProfiles, noteLines] = local_import_characterization_file(fullPath, cfg)
info = whos('-file', fullPath);
cellVarNames = string({info.name});
oxfordTable = local_empty_oxford_table();
ocvProfiles = local_empty_ocv_table();
noteLines = "Imported Oxford characterization file with per-cell sampled cycles.";

for cellIdx = 1:numel(cellVarNames)
    varName = char(cellVarNames(cellIdx));
    loaded = load(fullPath, varName);
    cellStruct = loaded.(varName);
    cycleNames = fieldnames(cellStruct);

    for cycIdx = 1:numel(cycleNames)
        cycName = cycleNames{cycIdx};
        cycleStruct = cellStruct.(cycName);
        if ~isstruct(cycleStruct)
            fprintf("Oxford import warning for %s/%s: unexpected cycle type.\n", varName, cycName);
            continue;
        end

        stageNames = fieldnames(cycleStruct);
        for stageIdx = 1:numel(stageNames)
            stageName = stageNames{stageIdx};
            if ~isstruct(cycleStruct.(stageName))
                fprintf("Oxford import warning for %s/%s/%s: unexpected stage type.\n", varName, cycName, stageName);
                continue;
            end

            cycleLabel = string(cycName) + "_" + string(stageName);
            part = local_parse_stage(cycleStruct.(stageName), stageName, string(varName), cycleLabel, cfg);
            if isempty(part)
                continue;
            end

            oxfordTable = [oxfordTable; part]; %#ok<AGROW>
            if contains(lower(stageName), "ocv")
                ocvProfiles = [ocvProfiles; local_profiles_from_table(part)]; %#ok<AGROW>
            end
        end
    end
end
end

function part = local_parse_stage(stageStruct, stageName, cellId, cycleId, cfg)
time_s = local_get_numeric_field(stageStruct, {'t', 'time'});
voltage_V = local_get_numeric_field(stageStruct, {'v', 'voltage'});

if isempty(time_s) || isempty(voltage_V)
    fprintf("Oxford import warning for %s %s: missing time or voltage, stage skipped.\n", cellId, cycleId);
    part = local_empty_oxford_table();
    return;
end

current_A = local_get_numeric_field(stageStruct, {'i', 'current'});
temp_C = local_get_numeric_field(stageStruct, {'T', 'temp', 'temperature'});
capacity_Ah = local_get_numeric_field(stageStruct, {'q', 'charge', 'capacity'});

time_s = local_make_column(time_s);
voltage_V = local_make_column(voltage_V);
current_A = local_make_column(current_A);
temp_C = local_make_column(temp_C);
capacity_Ah = local_make_column(capacity_Ah);

n = min([numel(time_s), numel(voltage_V), local_valid_length(temp_C), local_valid_length(current_A), local_valid_length(capacity_Ah)]);
if isinf(n) || n <= 1
    n = min(numel(time_s), numel(voltage_V));
end

time_s = time_s(1:n);
voltage_V = voltage_V(1:n);
current_A = local_trim_or_fill(current_A, n, NaN);
temp_C = local_trim_or_fill(temp_C, n, NaN);
capacity_Ah = local_trim_or_fill(capacity_Ah, n, NaN);

if max(time_s) > 1000
    time_s = time_s - time_s(1);
end

if all(isnan(current_A))
    current_A = local_default_current(stageName, n);
end
if max(abs(current_A), [], 'omitnan') > 20
    current_A = current_A ./ 1000;
end

if max(abs(capacity_Ah), [], 'omitnan') > 10
    capacity_Ah = capacity_Ah ./ 1000;
end

if all(isnan(temp_C))
    temp_C = repmat(cfg.processing.defaultOcvTemperature_C, n, 1);
end

soc_est = local_capacity_to_soc(capacity_Ah);
keepIdx = local_sample_indices(n, cfg.processing.maxRowsPerRecord);

part = table( ...
    time_s(keepIdx), voltage_V(keepIdx), current_A(keepIdx), temp_C(keepIdx), ...
    capacity_Ah(keepIdx), soc_est(keepIdx), ...
    repmat("Oxford", numel(keepIdx), 1), repmat(string(cellId), numel(keepIdx), 1), repmat(string(cycleId), numel(keepIdx), 1), ...
    'VariableNames', {'time_s', 'voltage_V', 'current_A', 'temp_C', 'capacity_Ah', 'soc_est', 'dataset_id', 'cell_id', 'cycle_id'});
end

function ocvProfiles = local_profiles_from_table(T)
ocvProfiles = local_empty_ocv_table();
if isempty(T)
    return;
end

groupId = findgroups(T.cell_id, T.cycle_id);
numGroups = max(groupId);
for idx = 1:numGroups
    part = T(groupId == idx, :);
    if height(part) < 10 || all(isnan(part.soc_est)) || all(isnan(part.voltage_V))
        continue;
    end
    soc = part.soc_est;
    valid = isfinite(soc) & isfinite(part.voltage_V);
    soc = soc(valid);
    volt = part.voltage_V(valid);
    temp = part.temp_C(valid);
    if numel(soc) < 10
        continue;
    end
    [socUnique, ia] = unique(round(soc, 4));
    if numel(socUnique) < 10
        continue;
    end
    tempMean = mean(temp, 'omitnan');
    if ~isfinite(tempMean)
        tempMean = 25;
    end
    sourceId = string(part.cell_id(1)) + "_" + string(part.cycle_id(1));
    ocvProfiles = [ocvProfiles; table( ...
        socUnique(:), volt(ia), repmat(tempMean, numel(socUnique), 1), ...
        repmat("Oxford", numel(socUnique), 1), repmat(sourceId, numel(socUnique), 1), ...
        'VariableNames', {'soc', 'ocv_V', 'temp_C', 'dataset_id', 'source_id'})]; %#ok<AGROW>
end
end

function current_A = local_default_current(stageName, n)
stageLower = lower(string(stageName));
if contains(stageLower, "ocvch")
    current_A = repmat(0.04, n, 1);
elseif contains(stageLower, "ocvdc")
    current_A = repmat(-0.04, n, 1);
elseif contains(stageLower, "c1ch") || stageLower == "ch"
    current_A = repmat(0.74, n, 1);
elseif contains(stageLower, "c1dc") || stageLower == "dc"
    current_A = repmat(-0.74, n, 1);
else
    current_A = zeros(n, 1);
end
end

function soc_est = local_capacity_to_soc(capacity_Ah)
if isempty(capacity_Ah) || all(~isfinite(capacity_Ah))
    soc_est = NaN(size(capacity_Ah));
    return;
end
q = capacity_Ah(:);
qMin = min(q, [], 'omitnan');
qMax = max(q, [], 'omitnan');
if ~isfinite(qMin) || ~isfinite(qMax) || abs(qMax - qMin) < eps
    soc_est = NaN(size(q));
    return;
end
soc_est = (q - qMin) ./ (qMax - qMin);
soc_est = max(min(soc_est, 1), 0);
end

function x = local_get_numeric_field(S, candidateNames)
x = [];
fields = fieldnames(S);
for idx = 1:numel(candidateNames)
    matchIdx = find(strcmp(fields, candidateNames{idx}), 1, 'first');
    if isempty(matchIdx)
        matchIdx = find(strcmpi(fields, candidateNames{idx}), 1, 'first');
    end
    if ~isempty(matchIdx)
        candidate = S.(fields{matchIdx});
        if isnumeric(candidate)
            x = candidate;
            return;
        end
    end
end
end

function x = local_make_column(x)
if isempty(x)
    x = [];
else
    x = double(x(:));
end
end

function n = local_valid_length(x)
if isempty(x)
    n = inf;
else
    n = numel(x);
end
end

function x = local_trim_or_fill(x, n, fillValue)
if isempty(x)
    x = repmat(fillValue, n, 1);
elseif numel(x) >= n
    x = x(1:n);
else
    x = interp1(linspace(0, 1, numel(x)), x, linspace(0, 1, n), 'linear', 'extrap').';
end
end

function idx = local_sample_indices(n, maxRows)
if n <= maxRows
    idx = (1:n).';
else
    idx = unique(round(linspace(1, n, maxRows))).';
end
end

function T = local_empty_oxford_table()
T = table( ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    strings(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'time_s', 'voltage_V', 'current_A', 'temp_C', 'capacity_Ah', 'soc_est', 'dataset_id', 'cell_id', 'cycle_id'});
end

function T = local_empty_ocv_table()
T = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'soc', 'ocv_V', 'temp_C', 'dataset_id', 'source_id'});
end

function ocvProfiles = local_filter_ocv_profiles(ocvProfiles)
if isempty(ocvProfiles)
    return;
end

sourceLower = lower(ocvProfiles.source_id);
hasTrueOcvStages = contains(sourceLower, "ocv");
if any(hasTrueOcvStages)
    ocvProfiles = ocvProfiles(hasTrueOcvStages, :);
    sourceLower = lower(ocvProfiles.source_id);
end

cycleNumbers = nan(height(ocvProfiles), 1);
for idx = 1:height(ocvProfiles)
    token = regexp(char(sourceLower(idx)), 'cyc(\d+)', 'tokens', 'once');
    if ~isempty(token)
        cycleNumbers(idx) = str2double(token{1});
    end
end

earlyMask = ~isnan(cycleNumbers) & cycleNumbers <= 1000;
if any(earlyMask)
    ocvProfiles = ocvProfiles(earlyMask, :);
end
end
