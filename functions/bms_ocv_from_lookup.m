function ocv_V = bms_ocv_from_lookup(lookup, soc, temp_C)
%BMS_OCV_FROM_LOOKUP Interpolate OCV from the lookup structure.

soc = max(min(soc, 1), 0);
if nargin < 3 || isempty(temp_C)
    temp_C = zeros(size(soc)) + lookup.temperature_grid_C(1);
end

tempGrid = lookup.temperature_grid_C(:);
socGrid = lookup.soc_grid(:);
ocvTable = lookup.ocv_grid_V;

if numel(tempGrid) == 1
    ocv_V = interp1(socGrid, ocvTable(:, 1), soc, "pchip", "extrap");
    return;
end

soc = soc(:);
temp_C = temp_C(:);
ocv_V = zeros(size(soc));

for idx = 1:numel(soc)
    ocvAcrossTemp = zeros(numel(tempGrid), 1);
    for tempIdx = 1:numel(tempGrid)
        ocvAcrossTemp(tempIdx) = interp1(socGrid, ocvTable(:, tempIdx), soc(idx), "pchip", "extrap");
    end
    ocv_V(idx) = interp1(tempGrid, ocvAcrossTemp, temp_C(idx), "linear", "extrap");
end
end
