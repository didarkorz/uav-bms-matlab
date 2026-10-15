function T = bms_standardize_timeseries(time_s, voltage_V, current_A, temp_C, capacity_Ah, datasetId, cellId, cycleId)
%BMS_STANDARDIZE_TIMESERIES Return the common table layout used in the project.

time_s = local_columnize(time_s);
n = numel(time_s);

voltage_V = local_expand(voltage_V, n, NaN);
current_A = local_expand(current_A, n, NaN);
temp_C = local_expand(temp_C, n, NaN);
capacity_Ah = local_expand(capacity_Ah, n, NaN);

dataset_id = repmat(string(datasetId), n, 1);
cell_id = repmat(string(cellId), n, 1);
cycle_id = repmat(string(cycleId), n, 1);

T = table(time_s, voltage_V, current_A, temp_C, capacity_Ah, dataset_id, cell_id, cycle_id);
end

function x = local_columnize(x)
if isempty(x)
    x = zeros(0, 1);
else
    x = double(x(:));
end
end

function x = local_expand(x, n, fillValue)
if isempty(x)
    x = repmat(fillValue, n, 1);
    return;
end

x = double(x(:));
if numel(x) == 1 && n > 1
    x = repmat(x, n, 1);
elseif numel(x) ~= n
    x = interp1(linspace(0, 1, numel(x)), x, linspace(0, 1, n), "linear", "extrap").';
end
end
