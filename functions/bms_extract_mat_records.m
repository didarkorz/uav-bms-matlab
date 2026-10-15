function records = bms_extract_mat_records(node, rootLabel)
%BMS_EXTRACT_MAT_RECORDS Recursively find t-v-(i/q/T) records inside MAT data.

if nargin < 2
    rootLabel = "root";
end

records = local_walk(node, {char(rootLabel)}, {});
end

function records = local_walk(node, pathParts, records)
if isstruct(node)
    if isscalar(node)
        rec = local_try_build_record(node, pathParts);
        if ~isempty(rec)
            records{end + 1, 1} = rec; %#ok<AGROW>
        end

        names = fieldnames(node);
        for idx = 1:numel(names)
            records = local_walk(node.(names{idx}), [pathParts, {names{idx}}], records);
        end
    else
        for idx = 1:numel(node)
            records = local_walk(node(idx), [pathParts, {sprintf('item_%03d', idx)}], records);
        end
    end
elseif iscell(node)
    for idx = 1:numel(node)
        records = local_walk(node{idx}, [pathParts, {sprintf('cell_%03d', idx)}], records);
    end
end
end

function rec = local_try_build_record(node, pathParts)
rec = [];
time_s = local_get_numeric(node, {"t", "time"});
voltage_V = local_get_numeric(node, {"v", "voltage"});

if isempty(time_s) || isempty(voltage_V)
    return;
end

temp_C = local_get_numeric(node, {"T", "temp", "temperature"});
current_A = local_get_numeric(node, {"i", "current"});
chargeRaw = local_get_numeric(node, {"q", "charge", "capacity"});

time_s = double(time_s(:));
voltage_V = double(voltage_V(:));
temp_C = double(temp_C(:));
current_A = double(current_A(:));
chargeRaw = double(chargeRaw(:));

n = min([numel(time_s), numel(voltage_V), local_nonzero_or_inf(temp_C), local_nonzero_or_inf(current_A), local_nonzero_or_inf(chargeRaw)]);
if isinf(n) || n <= 1
    n = min(numel(time_s), numel(voltage_V));
end

time_s = time_s(1:n);
voltage_V = voltage_V(1:n);
temp_C = local_trim_or_empty(temp_C, n);
current_A = local_trim_or_empty(current_A, n);
chargeRaw = local_trim_or_empty(chargeRaw, n);

if isempty(current_A) && ~isempty(chargeRaw) && numel(chargeRaw) > 1
    dt = [NaN; diff(time_s)];
    dq = [NaN; diff(chargeRaw)];
    current_A = 3.6 .* dq ./ max(dt, eps);
    firstValid = find(~isnan(current_A), 1, "first");
    if ~isempty(firstValid)
        current_A(1:firstValid - 1) = current_A(firstValid);
    else
        current_A = zeros(n, 1);
    end
end

if isempty(chargeRaw)
    if isempty(current_A)
        capacity_Ah = NaN(n, 1);
    else
        capacity_Ah = cumtrapz(time_s, abs(current_A)) ./ 3600;
    end
else
    if max(abs(chargeRaw)) > 10
        capacity_Ah = chargeRaw ./ 1000;
    else
        capacity_Ah = chargeRaw;
    end
end

[cellId, cycleId] = local_guess_ids(pathParts);

rec = struct();
rec.path = string(strjoin(pathParts, "/"));
rec.time_s = time_s;
rec.voltage_V = voltage_V;
rec.current_A = current_A;
rec.temp_C = temp_C;
rec.capacity_Ah = capacity_Ah;
rec.cell_id = cellId;
rec.cycle_id = cycleId;
end

function value = local_get_numeric(node, candidateNames)
value = [];
fields = fieldnames(node);
for idx = 1:numel(candidateNames)
    match = strcmpi(fields, candidateNames{idx});
    if any(match)
        raw = node.(fields{find(match, 1, "first")});
        if isnumeric(raw)
            value = raw;
            return;
        end
    end
end
end

function n = local_nonzero_or_inf(x)
if isempty(x)
    n = inf;
else
    n = numel(x);
end
end

function x = local_trim_or_empty(x, n)
if isempty(x)
    return;
end
if numel(x) >= n
    x = x(1:n);
else
    x = interp1(linspace(0, 1, numel(x)), x, linspace(0, 1, n), "linear", "extrap").';
end
end

function [cellId, cycleId] = local_guess_ids(pathParts)
cellId = "unknown_cell";
cycleId = "unknown_cycle";

for idx = 1:numel(pathParts)
    token = string(pathParts{idx});
    tokenLower = lower(token);
    if cellId == "unknown_cell"
        if contains(tokenLower, "cell") || ~isempty(regexp(tokenLower, "^c\d+$", "once"))
            cellId = token;
        end
    end
    if cycleId == "unknown_cycle"
        if contains(tokenLower, "cyc") || contains(tokenLower, "cycle") || contains(tokenLower, "ocv") || contains(tokenLower, "ch") || contains(tokenLower, "dc")
            cycleId = token;
        end
    end
end

if cellId == "unknown_cell" && ~isempty(pathParts)
    cellId = string(pathParts{min(2, numel(pathParts))});
end
if cycleId == "unknown_cycle" && ~isempty(pathParts)
    cycleId = string(pathParts{end});
end
end
