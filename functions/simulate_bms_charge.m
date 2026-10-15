function results = simulate_bms_charge(cfg)
%SIMULATE_BMS_CHARGE MATLAB-only charging simulation for the thesis project.
% This script-level model provides defendable plots even before the user
% assembles or fine-tunes the Simulink diagram.

time_s = cfg.sim.time_s;
numSteps = numel(time_s);
numCells = cfg.pack.numCells;
dt_s = cfg.sim.sampleTime_s;

soc = zeros(numSteps, numCells);
temperature_C = zeros(numSteps, numCells);
ocv_V = zeros(numSteps, numCells);
cellVoltage_V = zeros(numSteps, numCells);
balanceSignal = false(numSteps, numCells);
bleedCurrent_A = zeros(numSteps, numCells);

packVoltage_V = zeros(numSteps, 1);
chargeCurrent_A = zeros(numSteps, 1);
chargerMode = strings(numSteps, 1);
protectionActive = false(numSteps, 1);
terminationReason = strings(numSteps, 1);
packImbalance_V = zeros(numSteps, 1);
completionIndex = numSteps;

soc(1, :) = cfg.init.soc(:).';
temperature_C(1, :) = cfg.init.temperature_C(:).';
ocv_V(1, :) = ocv_from_soc(soc(1, :));
cellVoltage_V(1, :) = ocv_V(1, :);
packVoltage_V(1) = sum(cellVoltage_V(1, :));
chargerMode(1) = "CC";
terminationReason(1) = "Running";
packImbalance_V(1) = max(cellVoltage_V(1, :)) - min(cellVoltage_V(1, :));

balancePrev = false(numCells, 1);
cvModeLatched = false;
done = false;
topClamp_V = cfg.pack.maxCellVoltage_V - cfg.cell.topOfChargeClampMargin_V(:).';

for k = 2:numSteps
    if done
        soc(k, :) = soc(k - 1, :);
        temperature_C(k, :) = temperature_C(k - 1, :);
        ocv_V(k, :) = ocv_V(k - 1, :);
        cellVoltage_V(k, :) = cellVoltage_V(k - 1, :);
        packVoltage_V(k) = packVoltage_V(k - 1);
        chargeCurrent_A(k) = 0;
        balanceSignal(k, :) = false(1, numCells);
        bleedCurrent_A(k, :) = 0;
        chargerMode(k) = "DONE";
        protectionActive(k) = protectionActive(k - 1);
        terminationReason(k) = terminationReason(k - 1);
        packImbalance_V(k) = packImbalance_V(k - 1);
        continue;
    end

    ocvNow_V = ocv_from_soc(soc(k - 1, :));
    previousCellVoltage_V = cellVoltage_V(k - 1, :).';
    [balanceNow, bleedNow_A] = balancing_decision_logic(previousCellVoltage_V, cfg, balancePrev);
    balancePrev = balanceNow;

    maxTemp_C = max(temperature_C(k - 1, :));
    maxCell_V = max(previousCellVoltage_V);
    packVoltageEstimate_V = sum(previousCellVoltage_V);

    chargeLimit_A = cfg.charge.ccCurrent_A;
    chargerMode(k) = "CC";
    terminationReason(k) = "Running";
    cellCurrentLimit_A = inf;
    meanSocNow = mean(soc(k - 1, :));

    for cellIdx = 1:numCells
        headroom_V = topClamp_V(cellIdx) - previousCellVoltage_V(cellIdx);
        allowableCharge_A = max(0, headroom_V / ...
            (cfg.cell.internalResistance_Ohm(cellIdx) * cfg.cell.polarizationFactor(cellIdx))) ...
            + bleedNow_A(cellIdx);
        cellCurrentLimit_A = min(cellCurrentLimit_A, allowableCharge_A);
    end

    if isinf(cellCurrentLimit_A)
        cellCurrentLimit_A = cfg.charge.ccCurrent_A;
    end

    if cvModeLatched || packVoltageEstimate_V >= (cfg.charge.cvTargetPackVoltage_V - 0.01) ...
            || maxCell_V >= max(topClamp_V - 0.004)
        cvModeLatched = true;
        cvError_V = cfg.charge.cvTargetPackVoltage_V - packVoltageEstimate_V;
        packCvCurrent_A = max(0, min(cfg.charge.ccCurrent_A, cfg.charge.currentRampGain_A_per_V * cvError_V));
        socTaperFraction = max(0, min(1, ...
            (cfg.charge.completionSoC - meanSocNow) / ...
            max(cfg.charge.completionSoC - cfg.charge.cvTaperStartSoC, eps)));
        socTaperCurrent_A = cfg.charge.ccCurrent_A * socTaperFraction;
        chargeLimit_A = min([packCvCurrent_A, cellCurrentLimit_A, socTaperCurrent_A + cfg.charge.terminationCurrent_A]);
        chargerMode(k) = "CV";
    else
        chargeLimit_A = min(cfg.charge.ccCurrent_A, cellCurrentLimit_A);
    end

    if maxTemp_C >= cfg.safety.derateTemperature_C
        thermalScale = max(0, (cfg.safety.maxTemperature_C - maxTemp_C) ...
            / (cfg.safety.maxTemperature_C - cfg.safety.derateTemperature_C));
        chargeLimit_A = min(chargeLimit_A, thermalScale * cfg.charge.ccCurrent_A);
        terminationReason(k) = "Current limited by temperature derating";
    end

    if maxCell_V >= cfg.safety.maxCellVoltage_V || maxTemp_C >= cfg.safety.maxTemperature_C
        chargeLimit_A = 0;
        protectionActive(k) = true;
        chargerMode(k) = "STOP";
        done = true;
        completionIndex = k;
        if maxCell_V >= cfg.safety.maxCellVoltage_V
            terminationReason(k) = "Stopped by overvoltage protection";
        else
            terminationReason(k) = "Stopped by overtemperature protection";
        end
    end

    if ~done && cvModeLatched && chargeLimit_A <= cfg.charge.terminationCurrent_A ...
            && (packVoltageEstimate_V >= cfg.charge.cvTargetPackVoltage_V - cfg.charge.cvCompletionVoltageTolerance_V ...
            || maxCell_V >= max(topClamp_V - 0.003)) ...
            && meanSocNow >= cfg.charge.cvTaperStartSoC
        chargeLimit_A = 0;
        chargerMode(k) = "DONE";
        done = true;
        completionIndex = k;
        terminationReason(k) = "Charging completed normally (current cutoff reached)";
    end

    chargeCurrent_A(k) = chargeLimit_A;

    for cellIdx = 1:numCells
        netCellCurrent_A = max(chargeLimit_A - bleedNow_A(cellIdx), 0);
        soc(k, cellIdx) = soc_estimation( ...
            soc(k - 1, cellIdx), ...
            netCellCurrent_A, ...
            dt_s, ...
            cfg.pack.cellCapacity_As(cellIdx), ...
            cellVoltage_V(k - 1, cellIdx), ...
            cfg);

        ocv_V(k, cellIdx) = ocv_from_soc(soc(k, cellIdx));
        cellVoltageCandidate_V = ocv_V(k, cellIdx) + netCellCurrent_A * cfg.cell.internalResistance_Ohm(cellIdx) * cfg.cell.polarizationFactor(cellIdx);
        if chargerMode(k) == "CV" || chargerMode(k) == "DONE"
            cellVoltage_V(k, cellIdx) = min(cellVoltageCandidate_V, topClamp_V(cellIdx));
        else
            cellVoltage_V(k, cellIdx) = min(cellVoltageCandidate_V, min(topClamp_V(cellIdx) + 0.02, cfg.pack.maxCellVoltage_V));
        end

        temperature_C(k, cellIdx) = thermal_calculation( ...
            temperature_C(k - 1, cellIdx), ...
            netCellCurrent_A, ...
            bleedNow_A(cellIdx), ...
            cfg.cell.internalResistance_Ohm(cellIdx), ...
            cellVoltage_V(k, cellIdx), ...
            cfg.thermal.cellHeatCapacity_J_per_C(cellIdx), ...
            cfg.thermal.cellConvection_W_per_C(cellIdx), ...
            dt_s, ...
            cfg);
    end

    balanceSignal(k, :) = balanceNow;
    bleedCurrent_A(k, :) = bleedNow_A;
    packVoltage_V(k) = sum(cellVoltage_V(k, :));
    packImbalance_V(k) = max(cellVoltage_V(k, :)) - min(cellVoltage_V(k, :));

    if strcmp(chargerMode(k), "")
        chargerMode(k) = chargerMode(k - 1);
    end

    if strcmp(terminationReason(k), "")
        terminationReason(k) = terminationReason(k - 1);
    end
end

if completionIndex < numSteps
    validIdx = 1:completionIndex;
else
    validIdx = 1:numSteps;
    if all(terminationReason == "Running")
        terminationReason(end) = "Maximum simulation time reached (safety fallback)";
    end
end

results.time_s = time_s(validIdx);
results.soc = soc(validIdx, :);
results.temperature_C = temperature_C(validIdx, :);
results.ocv_V = ocv_V(validIdx, :);
results.cellVoltage_V = cellVoltage_V(validIdx, :);
results.packVoltage_V = packVoltage_V(validIdx);
results.chargeCurrent_A = chargeCurrent_A(validIdx);
results.balanceSignal = balanceSignal(validIdx, :);
results.bleedCurrent_A = bleedCurrent_A(validIdx, :);
results.chargerMode = chargerMode(validIdx);
results.protectionActive = protectionActive(validIdx);
results.terminationReason = terminationReason(validIdx);
results.packImbalance_V = packImbalance_V(validIdx);
results.completionTime_s = results.time_s(end);
results.cutoffCurrent_A = cfg.charge.terminationCurrent_A;
end
