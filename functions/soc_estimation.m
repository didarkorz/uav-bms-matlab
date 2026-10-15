function socNext = soc_estimation(socPrev, chargeCurrent_A, dt_s, capacity_As, measuredVoltage_V, cfg)
%SOC_ESTIMATION Coulomb counting with optional low-current voltage correction.
% Positive current represents charging current into the cell.

socCoulomb = socPrev + (chargeCurrent_A * dt_s / capacity_As);

if cfg.soc.enableVoltageCorrection && abs(chargeCurrent_A) <= cfg.soc.blendCurrentThreshold_A
    socFromVoltage = min(max((measuredVoltage_V - 3.0) / 1.2, 0), 1);
    socNext = (1 - cfg.soc.voltageCorrectionGain) * socCoulomb ...
        + cfg.soc.voltageCorrectionGain * socFromVoltage;
else
    socNext = socCoulomb;
end

socNext = min(max(socNext, 0), 1);
end
