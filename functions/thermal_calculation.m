    function tempNext_C = thermal_calculation(tempPrev_C, cellCurrent_A, bleedCurrent_A, internalResistance_Ohm, cellVoltage_V, heatCapacity_J_per_C, convection_W_per_C, dt_s, cfg)
%THERMAL_CALCULATION First-order thermal update for one cell.
% Heat sources:
% 1. Joule heating due to charging current and cell internal resistance.
% 2. Bleed resistor heating during passive balancing.

jouleHeat_W = (cellCurrent_A ^ 2) * internalResistance_Ohm;
bleedHeat_W = cfg.thermal.balanceHeatFraction * (cellVoltage_V ^ 2 / cfg.balance.resistor_Ohm) * double(bleedCurrent_A > 0);
totalHeat_W = jouleHeat_W + bleedHeat_W;

cooling_W = convection_W_per_C * (tempPrev_C - cfg.thermal.ambient_C);
tempRate_C_per_s = (totalHeat_W - cooling_W) / heatCapacity_J_per_C;

tempNext_C = tempPrev_C + dt_s * tempRate_C_per_s;
end
