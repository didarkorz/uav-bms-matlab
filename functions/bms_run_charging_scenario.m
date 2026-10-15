function results = bms_run_charging_scenario(packModel, scenario, cfg)
%BMS_RUN_CHARGING_SCENARIO Simulate CC-CV charging for one BMS scenario.

cells = packModel.cells;
lookup = packModel.ocv_lookup;
nCells = numel(cells);
time_s = cfg.sim.time_s(:);
nSteps = numel(time_s);
dt_s = cfg.sim.dt_s;

Qn_Ah = reshape([cells.capacity_Ah], 1, []);
R0 = reshape([cells.R0_Ohm], 1, []);
R1 = reshape([cells.R1_Ohm], 1, []);
C1 = reshape([cells.C1_F], 1, []);
eta = reshape([cells.eta_charge], 1, []);
Cth = reshape([cells.Cth_J_per_C], 1, []);
hA = reshape([cells.hA_W_per_C], 1, []);

soc = zeros(nSteps, nCells);
temperature_C = zeros(nSteps, nCells);
vrc_V = zeros(nSteps, nCells);
ocv_V = zeros(nSteps, nCells);
cell_voltage_V = zeros(nSteps, nCells);
cell_current_A = zeros(nSteps, nCells);
balance_current_A = zeros(nSteps, nCells);
balance_power_W = zeros(nSteps, nCells);
balance_signal = false(nSteps, nCells);
pack_voltage_V = zeros(nSteps, 1);
charge_current_A = zeros(nSteps, 1);
pack_imbalance_V = zeros(nSteps, 1);
mode = strings(nSteps, 1);
imbalance_derating_applied = false;
temperature_derating_applied = false;
overvoltage_predicted = false;
cutoff_reached = false;
current_derate_factor = ones(nSteps, 1);

soc(1, :) = reshape([cells.initial_soc], 1, []);
temperature_C(1, :) = reshape([cells.initial_temp_C], 1, []);
ocv_V(1, :) = reshape(bms_ocv_from_lookup(lookup, soc(1, :).', temperature_C(1, :).'), 1, []);
cell_voltage_V(1, :) = ocv_V(1, :);
pack_voltage_V(1) = sum(cell_voltage_V(1, :));
pack_imbalance_V(1) = max(cell_voltage_V(1, :)) - min(cell_voltage_V(1, :));
mode(1) = "CC";

cvLatched = false;
balanceState = false(1, nCells);
terminationReason = "Maximum simulation time reached";
lastIdx = nSteps;

for k = 1:nSteps - 1
    ocv_V(k, :) = reshape(bms_ocv_from_lookup(lookup, soc(k, :).', temperature_C(k, :).'), 1, []);

    if k > 1
        cell_voltage_V(k, :) = ocv_V(k, :) + vrc_V(k, :) + cell_current_A(k - 1, :) .* R0;
        pack_voltage_V(k) = sum(cell_voltage_V(k, :));
        pack_imbalance_V(k) = max(cell_voltage_V(k, :)) - min(cell_voltage_V(k, :));
    end

    [balance_signal(k, :), balance_current_A(k, :)] = local_balance( ...
        cell_voltage_V(k, :), scenario, balanceState, cfg);
    balanceState = balance_signal(k, :);

    cellLimit_A = local_cell_current_limit(ocv_V(k, :), vrc_V(k, :), R0, balance_current_A(k, :), cfg.pack.maxCellVoltage_V);
    ccCurrent_A = min([cfg.charger.ccCurrent_A, cellLimit_A]);

    packBase_V = sum(ocv_V(k, :) + vrc_V(k, :) - balance_current_A(k, :) .* R0);
    packCvCurrent_A = max(0, (cfg.charger.cvTargetPackVoltage_V - packBase_V) / max(sum(R0), eps));

    if cvLatched || pack_voltage_V(k) >= cfg.charger.cvTargetPackVoltage_V - 0.02 || max(cell_voltage_V(k, :)) >= scenario.cvEntryCellVoltage_V
        cvLatched = true;
        currentCmd_A = min([cfg.charger.ccCurrent_A, cellLimit_A, packCvCurrent_A]);
        mode(k) = "CV";
    else
        currentCmd_A = min([cfg.charger.ccCurrent_A, cellLimit_A]);
        mode(k) = "CC";
    end

    maxTemp_C = max(temperature_C(k, :));
    imbalance_V = max(cell_voltage_V(k, :)) - min(cell_voltage_V(k, :));
    [currentCmd_A, tempScale, imbalanceScale] = local_apply_derating(currentCmd_A, maxTemp_C, imbalance_V, scenario, cfg);
    temperature_derating_applied = temperature_derating_applied || tempScale < 0.999;
    imbalance_derating_applied = imbalance_derating_applied || imbalanceScale < 0.999;
    if ~isfinite(currentCmd_A)
        currentCmd_A = 0;
    end
    currentCmd_A = max(0, currentCmd_A);
    current_derate_factor(k) = min(tempScale, imbalanceScale);

    if scenario.name == "baseline_no_balancing" && min(cellLimit_A) <= (0.5 * cfg.charger.currentCutoff_A) && mean(soc(k, :)) < 0.97
        currentCmd_A = 0;
        mode(k) = "STOP";
        terminationReason = "First cell reached voltage limit before balancing could reduce mismatch";
        lastIdx = k + 1;
        soc(k + 1, :) = soc(k, :);
        temperature_C(k + 1, :) = temperature_C(k, :);
        vrc_V(k + 1, :) = vrc_V(k, :);
        ocv_V(k + 1, :) = ocv_V(k, :);
        cell_voltage_V(k + 1, :) = cell_voltage_V(k, :);
        pack_voltage_V(k + 1) = pack_voltage_V(k);
        pack_imbalance_V(k + 1) = pack_imbalance_V(k);
        charge_current_A(k + 1) = 0;
        mode(k + 1) = "STOP";
        break;
    end

    if maxTemp_C >= cfg.thermal.protectionTemperature_C
        currentCmd_A = 0;
        mode(k) = "STOP";
        terminationReason = "Stopped by overtemperature protection";
        lastIdx = k + 1;
        soc(k + 1, :) = soc(k, :);
        temperature_C(k + 1, :) = temperature_C(k, :);
        vrc_V(k + 1, :) = vrc_V(k, :);
        ocv_V(k + 1, :) = ocv_V(k, :);
        cell_voltage_V(k + 1, :) = cell_voltage_V(k, :);
        pack_voltage_V(k + 1) = pack_voltage_V(k);
        pack_imbalance_V(k + 1) = pack_imbalance_V(k);
        charge_current_A(k + 1) = 0;
        mode(k + 1) = "STOP";
        break;
    end

    charge_current_A(k) = currentCmd_A;
    cell_current_A(k, :) = max(currentCmd_A - balance_current_A(k, :), 0);
    balance_power_W(k, :) = balance_signal(k, :) .* (cell_voltage_V(k, :) .^ 2 ./ max(scenario.balance.resistor_Ohm, 1));

    socNext = soc(k, :) + eta .* cell_current_A(k, :) * dt_s ./ (3600 .* Qn_Ah);
    if scenario.ocvCorrection && (currentCmd_A <= cfg.socCorrection.currentThreshold_A || mode(k) == "CV")
        ocvEstimate_V = cell_voltage_V(k, :) - cell_current_A(k, :) .* R0 - vrc_V(k, :);
        socFromVoltage = reshape(bms_soc_from_ocv(lookup, ocvEstimate_V.', temperature_C(k, :).'), 1, []);
        socNext = (1 - cfg.socCorrection.blendGain) .* socNext + cfg.socCorrection.blendGain .* socFromVoltage;
    end
    soc(k + 1, :) = max(min(socNext, 1), 0);

    alpha = exp(-dt_s ./ max(R1 .* C1, eps));
    vrc_V(k + 1, :) = alpha .* vrc_V(k, :) + (1 - alpha) .* R1 .* cell_current_A(k, :);

    thermalDot_C_per_s = ((cell_current_A(k, :) .^ 2) .* R0 + balance_power_W(k, :) - hA .* (temperature_C(k, :) - cfg.thermal.ambient_C)) ./ Cth;
    temperature_C(k + 1, :) = temperature_C(k, :) + dt_s .* thermalDot_C_per_s;

    ocv_V(k + 1, :) = reshape(bms_ocv_from_lookup(lookup, soc(k + 1, :).', temperature_C(k + 1, :).'), 1, []);
    cell_voltage_V(k + 1, :) = ocv_V(k + 1, :) + vrc_V(k + 1, :) + cell_current_A(k, :) .* R0;
    pack_voltage_V(k + 1) = sum(cell_voltage_V(k + 1, :));
    pack_imbalance_V(k + 1) = max(cell_voltage_V(k + 1, :)) - min(cell_voltage_V(k + 1, :));

    if cvLatched && currentCmd_A <= cfg.charger.currentCutoff_A && mean(soc(k + 1, :)) >= cfg.charger.minCompletionSoC
        charge_current_A(k + 1) = 0;
        mode(k + 1) = "DONE";
        terminationReason = "Charging ended by current cutoff";
        cutoff_reached = true;
        lastIdx = k + 1;
        break;
    end

    if any(cell_voltage_V(k + 1, :) > cfg.pack.maxCellVoltage_V + 1e-4)
        mode(k + 1) = "STOP";
        terminationReason = "Stopped after predicted overvoltage";
        overvoltage_predicted = true;
        lastIdx = k + 1;
        break;
    end

    if k == nSteps - 1
        lastIdx = nSteps;
    end
end

if lastIdx == nSteps && terminationReason == "Maximum simulation time reached"
    mode(mode == "") = "CC";
end

usedIdx = 1:lastIdx;
results = struct();
results.scenario_name = scenario.name;
results.scenario_title = scenario.title;
results.time_s = time_s(usedIdx);
results.soc = soc(usedIdx, :);
results.temperature_C = temperature_C(usedIdx, :);
results.vrc_V = vrc_V(usedIdx, :);
results.ocv_V = ocv_V(usedIdx, :);
results.cell_voltage_V = cell_voltage_V(usedIdx, :);
results.cell_current_A = cell_current_A(usedIdx, :);
results.balance_current_A = balance_current_A(usedIdx, :);
results.balance_power_W = balance_power_W(usedIdx, :);
results.balance_signal = balance_signal(usedIdx, :);
results.pack_voltage_V = pack_voltage_V(usedIdx);
results.pack_imbalance_V = pack_imbalance_V(usedIdx);
results.charge_current_A = charge_current_A(usedIdx);
results.mode = mode(usedIdx);
results.termination_reason = terminationReason;
results.overvoltage_predicted = overvoltage_predicted;
results.cutoff_reached = cutoff_reached;
results.temperature_derating_applied = temperature_derating_applied;
results.imbalance_derating_applied = imbalance_derating_applied;
results.current_derate_factor = current_derate_factor(usedIdx);
end

function [balanceOn, balanceCurrent_A] = local_balance(cellVoltage_V, scenario, previousState, cfg)
nCells = numel(cellVoltage_V);
balanceOn = false(1, nCells);
balanceCurrent_A = zeros(1, nCells);

if ~scenario.balance.enable
    return;
end

minCell_V = min(cellVoltage_V);
for idx = 1:nCells
    delta_V = cellVoltage_V(idx) - minCell_V;
    startCondition = cellVoltage_V(idx) >= scenario.balance.startVoltage_V && delta_V >= scenario.balance.threshold_V;
    holdCondition = previousState(idx) && cellVoltage_V(idx) >= (scenario.balance.startVoltage_V - scenario.balance.hysteresis_V) ...
        && delta_V >= max(0.5 * scenario.balance.threshold_V, 0.004);
    if startCondition || holdCondition
        balanceOn(idx) = true;
        balanceCurrent_A(idx) = min(cfg.balance.maxBleedCurrent_A, cellVoltage_V(idx) / scenario.balance.resistor_Ohm);
    end
end
end

function cellLimit_A = local_cell_current_limit(ocv_V, vrc_V, R0, balanceCurrent_A, maxCellVoltage_V)
baseTerm_V = ocv_V + vrc_V - balanceCurrent_A .* R0;
cellLimit_A = max(0, (maxCellVoltage_V - baseTerm_V) ./ max(R0, eps));
end

function [currentCmd_A, tempScale, imbalanceScale] = local_apply_derating(currentCmd_A, maxTemp_C, imbalance_V, scenario, cfg)
tempScale = 1;
if maxTemp_C >= scenario.temperatureDerateStart_C
    tempScale = (cfg.thermal.protectionTemperature_C - maxTemp_C) / ...
        max(cfg.thermal.protectionTemperature_C - scenario.temperatureDerateStart_C, eps);
    tempScale = min(max(tempScale, 0.05), 1.0);
end

imbalanceScale = 1;
if scenario.adaptiveCurrentReduction && imbalance_V >= scenario.imbalanceDerateStart_V
    imbalanceScale = 1 - (imbalance_V - scenario.imbalanceDerateStart_V) / max(0.08 - scenario.imbalanceDerateStart_V, eps);
    imbalanceScale = min(max(imbalanceScale, 0.20), 1.0);
end

currentCmd_A = currentCmd_A .* min(tempScale, imbalanceScale);
end
