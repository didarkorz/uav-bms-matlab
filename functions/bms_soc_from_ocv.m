function soc = bms_soc_from_ocv(lookup, ocv_V, temp_C)
%BMS_SOC_FROM_OCV Invert the OCV table for SoC correction.

if nargin < 3 || isempty(temp_C)
    temp_C = zeros(size(ocv_V)) + lookup.temperature_grid_C(1);
end

tempGrid = lookup.temperature_grid_C(:);
socGrid = lookup.soc_grid(:);
ocvTable = lookup.ocv_grid_V;

ocv_V = ocv_V(:);
temp_C = temp_C(:);
soc = zeros(size(ocv_V));

for idx = 1:numel(ocv_V)
    if numel(tempGrid) == 1
        ocvCurve = ocvTable(:, 1);
    else
        curveByTemp = zeros(numel(tempGrid), 1);
        for tempIdx = 1:numel(tempGrid)
            curveByTemp(tempIdx) = tempGrid(tempIdx);
        end
        tempLow = find(tempGrid <= temp_C(idx), 1, "last");
        tempHigh = find(tempGrid >= temp_C(idx), 1, "first");
        if isempty(tempLow)
            tempLow = 1;
        end
        if isempty(tempHigh)
            tempHigh = numel(tempGrid);
        end
        if tempLow == tempHigh
            ocvCurve = ocvTable(:, tempLow);
        else
            weight = (temp_C(idx) - tempGrid(tempLow)) / max(tempGrid(tempHigh) - tempGrid(tempLow), eps);
            ocvCurve = (1 - weight) * ocvTable(:, tempLow) + weight * ocvTable(:, tempHigh);
        end
    end
    [ocvUnique, uniqueIdx] = unique(ocvCurve);
    soc(idx) = interp1(ocvUnique, socGrid(uniqueIdx), ocv_V(idx), "linear", "extrap");
end

soc = max(min(soc, 1), 0);
end
