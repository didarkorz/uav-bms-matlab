function lookup = bms_build_ocv_lookup(oxfordProfiles, calceProfiles, cfg)
%BMS_BUILD_OCV_LOOKUP Build a lookup table from Oxford/CALCE profile points.

if nargin < 1 || isempty(oxfordProfiles)
    oxfordProfiles = table();
end
if nargin < 2 || isempty(calceProfiles)
    calceProfiles = table();
end

socGrid = cfg.processing.ocvSocGrid;
allProfiles = [oxfordProfiles; calceProfiles];

if isempty(allProfiles)
    tempGrid = cfg.processing.defaultOcvTemperature_C;
    ocvGrid = local_fallback_curve(socGrid);
    pointTable = table(socGrid(:), repmat(tempGrid, numel(socGrid), 1), ocvGrid(:), ...
        repmat("fallback", numel(socGrid), 1), ...
        'VariableNames', {'soc', 'temp_C', 'ocv_V', 'dataset_id'});
else
    allProfiles = allProfiles(~isnan(allProfiles.soc) & ~isnan(allProfiles.ocv_V), :);
    if isempty(allProfiles)
        tempGrid = cfg.processing.defaultOcvTemperature_C;
        ocvGrid = local_fallback_curve(socGrid);
        pointTable = table(socGrid(:), repmat(tempGrid, numel(socGrid), 1), ocvGrid(:), ...
            repmat("fallback", numel(socGrid), 1), ...
            'VariableNames', {'soc', 'temp_C', 'ocv_V', 'dataset_id'});
    else
        if ~ismember("temp_C", allProfiles.Properties.VariableNames)
            allProfiles.temp_C = repmat(cfg.processing.defaultOcvTemperature_C, height(allProfiles), 1);
        end
        invalidTemp = ~isfinite(allProfiles.temp_C) | abs(allProfiles.temp_C) > 100;
        allProfiles.temp_C(invalidTemp) = cfg.processing.defaultOcvTemperature_C;
        tempGrid = unique(round(allProfiles.temp_C ./ 5) .* 5);
        tempGrid = tempGrid(~isnan(tempGrid));
        if isempty(tempGrid)
            tempGrid = cfg.processing.defaultOcvTemperature_C;
        end

        ocvGrid = zeros(numel(socGrid), numel(tempGrid));
        pointTable = table();
        for tempIdx = 1:numel(tempGrid)
            temp_C = tempGrid(tempIdx);
            mask = abs(allProfiles.temp_C - temp_C) <= max(cfg.processing.temperatureTolerance_C, 2.5);
            tempSubset = allProfiles(mask, :);
            if isempty(tempSubset)
                ocvGrid(:, tempIdx) = local_fallback_curve(socGrid);
                continue;
            end

            [socUnique, ~, groupIndex] = unique(round(tempSubset.soc, 4));
            ocvMean = accumarray(groupIndex, tempSubset.ocv_V, [], @mean);
            if numel(socUnique) < 2
                ocvInterp = local_fallback_curve(socGrid);
            else
                ocvInterp = interp1(socUnique, ocvMean, socGrid, "pchip", "extrap");
            end
            ocvInterp = max(min(ocvInterp(:), cfg.pack.maxCellVoltage_V), cfg.pack.minCellVoltage_V);
            ocvInterp = cummax(ocvInterp);
            if max(ocvInterp) < 4.05 || min(ocvInterp) > 3.20 || (max(ocvInterp) - min(ocvInterp)) < 0.8
                ocvInterp = local_fallback_curve(socGrid);
            end
            ocvGrid(:, tempIdx) = ocvInterp;

            tempTable = table(socGrid(:), repmat(temp_C, numel(socGrid), 1), ocvInterp(:), ...
                repmat("measured", numel(socGrid), 1), ...
                'VariableNames', {'soc', 'temp_C', 'ocv_V', 'dataset_id'});
            pointTable = [pointTable; tempTable]; %#ok<AGROW>
        end

        [tempGrid, ocvGrid, pointTable] = local_ensure_default_temperature_curve( ...
            tempGrid, ocvGrid, pointTable, cfg);
    end
end

lookup = struct();
lookup.soc_grid = socGrid;
lookup.temperature_grid_C = tempGrid(:).';
lookup.ocv_grid_V = ocvGrid;
lookup.table = pointTable;
lookup.datasets_used = unique(string(pointTable.dataset_id));
end

function ocv = local_fallback_curve(socGrid)
knotsSoc = [0.00 0.05 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00];
knotsOcv = [3.00 3.42 3.54 3.66 3.72 3.76 3.80 3.84 3.89 3.97 4.08 4.20];
ocv = interp1(knotsSoc, knotsOcv, socGrid, "pchip", "extrap");
end

function [tempGrid, ocvGrid, pointTable] = local_ensure_default_temperature_curve(tempGrid, ocvGrid, pointTable, cfg)
defaultTemp = cfg.processing.defaultOcvTemperature_C;
if any(abs(tempGrid - defaultTemp) <= max(cfg.processing.temperatureTolerance_C, 2.5))
    return;
end

fallbackCurve = local_fallback_curve(cfg.processing.ocvSocGrid);
tempGrid = [tempGrid(:); defaultTemp];
ocvGrid = [ocvGrid, fallbackCurve(:)];
fallbackTable = table(cfg.processing.ocvSocGrid(:), repmat(defaultTemp, numel(cfg.processing.ocvSocGrid), 1), fallbackCurve(:), ...
    repmat("fallback", numel(cfg.processing.ocvSocGrid), 1), ...
    'VariableNames', {'soc', 'temp_C', 'ocv_V', 'dataset_id'});
pointTable = [pointTable; fallbackTable]; %#ok<AGROW>

[tempGrid, order] = sort(tempGrid(:).');
ocvGrid = ocvGrid(:, order);
end
