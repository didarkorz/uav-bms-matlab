function summary = bms_summarize_results(results, cfg)
%BMS_SUMMARIZE_RESULTS Create numeric summary metrics for a scenario run.

if numel(results.time_s) > 1
    dt_s = results.time_s(2) - results.time_s(1);
else
    dt_s = cfg.sim.dt_s;
end

ccDuration_s = sum(results.mode == "CC") * dt_s;
cvDuration_s = sum(results.mode == "CV") * dt_s;
totalTime_s = results.time_s(end);
finalVoltages = results.cell_voltage_V(end, :);
finalSoc = results.soc(end, :);
maxTemp_C = max(results.temperature_C, [], "all");
finalImbalance_V = max(finalVoltages) - min(finalVoltages);
finalSocSpread_pct = (max(finalSoc) - min(finalSoc)) * 100;
maxCellVoltage_V = max(results.cell_voltage_V, [], "all");
finalPackVoltage_V = results.pack_voltage_V(end);
balanceEnergy_Wh = sum(results.balance_power_W, 1) .* dt_s ./ 3600;
balanceEnergyTotal_Wh = sum(balanceEnergy_Wh);

endedByCutoff = contains(lower(string(results.termination_reason)), "cutoff");
endedByTime = contains(lower(string(results.termination_reason)), "time");
overvoltagePredicted = false;
cutoffReached = endedByCutoff;
temperatureDeratingApplied = false;
imbalanceDeratingApplied = false;
if isfield(results, "overvoltage_predicted")
    overvoltagePredicted = logical(results.overvoltage_predicted);
end
if isfield(results, "cutoff_reached")
    cutoffReached = logical(results.cutoff_reached);
end
if isfield(results, "temperature_derating_applied")
    temperatureDeratingApplied = logical(results.temperature_derating_applied);
end
if isfield(results, "imbalance_derating_applied")
    imbalanceDeratingApplied = logical(results.imbalance_derating_applied);
end

if maxCellVoltage_V > cfg.targets.maxCellVoltage_V + 1e-4 || maxTemp_C > cfg.targets.maxTemperature_C + 0.5
    status = cfg.reporting.statusFailName;
elseif endedByCutoff && finalImbalance_V < cfg.targets.finalVoltageImbalance_V ...
        && finalSocSpread_pct < cfg.targets.finalSoCSpread_pct ...
        && maxTemp_C < cfg.targets.maxTemperature_C
    status = cfg.reporting.statusPassName;
else
    status = cfg.reporting.statusWarnName;
end

summary = table( ...
    string(results.scenario_name), string(results.scenario_title), string(status), string(results.termination_reason), ...
    ccDuration_s, cvDuration_s, totalTime_s, ...
    finalVoltages(1), finalVoltages(2), finalVoltages(3), finalVoltages(4), ...
    finalSoc(1), finalSoc(2), finalSoc(3), finalSoc(4), ...
    maxTemp_C, maxCellVoltage_V, finalPackVoltage_V, finalImbalance_V, finalSocSpread_pct, balanceEnergyTotal_Wh, ...
    overvoltagePredicted, cutoffReached, endedByTime, temperatureDeratingApplied, imbalanceDeratingApplied, ...
    'VariableNames', { ...
    'scenario_name', 'scenario_title', 'status', 'termination_reason', ...
    'cc_duration_s', 'cv_duration_s', 'total_charging_time_s', ...
    'final_V1_V', 'final_V2_V', 'final_V3_V', 'final_V4_V', ...
    'final_SOC1', 'final_SOC2', 'final_SOC3', 'final_SOC4', ...
    'max_temperature_C', 'max_cell_voltage_V', 'final_pack_voltage_V', 'final_voltage_imbalance_V', 'final_soc_spread_pct', 'balancing_energy_Wh', ...
    'overvoltage_predicted', 'ended_by_cutoff', 'ended_by_time', 'temperature_derating_applied', 'imbalance_derating_applied' ...
    });
end
