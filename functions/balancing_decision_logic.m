function [balanceOn, bleedCurrent_A] = balancing_decision_logic(cellVoltages_V, cfg, previousBalanceOn)
%BALANCING_DECISION_LOGIC Decide which cells should activate passive balancing.
% A cell is bled when:
% 1. Pack balancing is enabled,
% 2. The cell is sufficiently close to full charge, and
% 3. Its voltage is above the minimum pack voltage by a defined imbalance margin.

if nargin < 3
    previousBalanceOn = false(size(cellVoltages_V));
end

balanceOn = false(size(cellVoltages_V));
bleedCurrent_A = zeros(size(cellVoltages_V));

if ~cfg.balance.enable
    return;
end

minCell_V = min(cellVoltages_V);

for idx = 1:numel(cellVoltages_V)
    highCell = cellVoltages_V(idx) >= (minCell_V + cfg.balance.deltaTrigger_V);
    aboveStart = cellVoltages_V(idx) >= cfg.balance.startVoltage_V;
    aboveHold = cellVoltages_V(idx) >= (cfg.balance.startVoltage_V - cfg.balance.hysteresis_V);

    if (aboveStart && highCell) || (previousBalanceOn(idx) && aboveHold)
        balanceOn(idx) = true;
        bleedCurrent_A(idx) = cellVoltages_V(idx) / cfg.balance.resistor_Ohm;
    end
end
end
