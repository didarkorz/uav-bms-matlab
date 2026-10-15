function parameterAudit = bms_build_parameter_audit(cfg, estimates)
%BMS_BUILD_PARAMETER_AUDIT Build a diploma-ready parameter traceability table.

if nargin < 2
    estimates = struct();
end

rows = {
    "number_of_cells", string(cfg.pack.numCells), "cells", "pack design", "4-series UAV pack architecture used throughout the thesis", "engineering assumption"
    "nominal_cell_voltage", string(cfg.pack.nominalCellVoltage_V), "V", "LiPo nominal value", "Standard nominal voltage for lithium-polymer cell representation", "literature"
    "maximum_cell_voltage", string(cfg.pack.maxCellVoltage_V), "V", "LiPo charge limit", "Conservative upper voltage limit for CC-CV charging control", "literature"
    "minimum_safe_voltage", string(cfg.pack.minCellVoltage_V), "V", "LiPo discharge safety limit", "Lower bound used for safe cell operation reference", "literature"
    "nominal_cell_capacity", string(cfg.pack.nominalCellCapacity_Ah), "Ah", "UAV pack target", "Nominal design capacity for the virtual 4S pack", "engineering assumption"
    "cell_capacities", string(mat2str(cfg.cells.capacity_Ah, 3)), "Ah", "virtual pack mismatch", "Slight capacity spread added to create realistic balancing demand", "engineering assumption"
    "internal_resistances_R0", string(mat2str(cfg.cells.R0_Ohm, 4)), "Ohm", "identified average plus spread", "Chosen around the estimated mean resistance and deliberately mismatched per cell", "dataset + engineering assumption"
    "initial_soc_values", string(mat2str(cfg.cells.initialSoC, 3)), "-", "initial condition design", "Offset initial SoC values used to demonstrate imbalance and balancing behavior", "engineering assumption"
    "initial_temperature_values", string(mat2str(cfg.cells.initialTemp_C, 3)), "degC", "initial condition design", "Small temperature spread used for realistic startup conditions", "engineering assumption"
    "basic_balancing_resistor", string(cfg.balance.basic.resistor_Ohm), "Ohm", "baseline controller setting", "Represents a modest passive balancing branch for the basic controller", "engineering assumption"
    "improved_balancing_resistor", string(cfg.balance.improved.resistor_Ohm), "Ohm", "improved controller setting", "Lower resistor value increases bleed current for the improved controller", "engineering assumption"
    "basic_balancing_threshold", string(cfg.balance.basic.threshold_V), "V", "baseline controller setting", "Voltage spread needed before basic balancing activates", "engineering assumption"
    "improved_balancing_threshold", string(cfg.balance.improved.threshold_V), "V", "improved controller setting", "Earlier balancing trigger to reduce top-of-charge mismatch", "engineering assumption"
    "basic_balancing_start_voltage", string(cfg.balance.basic.startVoltage_V), "V", "baseline controller setting", "Balancing in the basic controller starts only close to full charge", "engineering assumption"
    "improved_balancing_start_voltage", string(cfg.balance.improved.startVoltage_V), "V", "improved controller setting", "Balancing starts earlier to reduce later overvoltage risk", "engineering assumption"
    "cc_current", string(cfg.charger.ccCurrent_A), "A", "0.5C engineering setting", "Moderate constant-current charging level for a 5 Ah UAV pack", "engineering assumption"
    "cv_voltage", string(cfg.charger.cvTargetPackVoltage_V), "V", "4S pack voltage limit", "4-cell series CV target equal to 4 x 4.2 V", "literature"
    "cutoff_current", string(cfg.charger.currentCutoff_A), "A", "0.05C engineering setting", "End-of-charge cutoff aligned with standard CC-CV practice", "engineering assumption"
    "ambient_temperature", string(cfg.thermal.ambient_C), "degC", "laboratory ambient assumption", "Reference ambient used in the lumped thermal model", "engineering assumption"
    "maximum_temperature", string(cfg.thermal.maxTemperature_C), "degC", "conservative BMS thermal limit", "Maximum acceptable temperature used for performance targets", "literature"
    "thermal_protection_temperature", string(cfg.thermal.protectionTemperature_C), "degC", "protection setting", "Hard stop threshold above the softer thermal target", "engineering assumption"
    "thermal_capacitances", string(mat2str(cfg.cells.Cth_J_per_C, 4)), "J/degC", "lumped thermal model", "First-order cell thermal capacities used for simulation", "engineering assumption"
    "cooling_coefficients_hA", string(mat2str(cfg.cells.hA_W_per_C, 4)), "W/degC", "lumped thermal model", "Effective convection terms for cell cooling to ambient", "engineering assumption"
    "ocv_lookup_temperature", "25", "degC", "Oxford data or fallback OCV table", "Only the available 25 degC-compatible OCV table was used in the current project state", "dataset + fallback"
    };

if isfield(estimates, "Qn_est_Ah")
    rows(end + 1, :) = {"estimated_nominal_capacity", string(estimates.Qn_est_Ah), "Ah", "processed NASA/Oxford data", "Estimated nominal capacity used as a plausibility check against the design value", "dataset"};
end
if isfield(estimates, "R0_est_Ohm")
    rows(end + 1, :) = {"estimated_average_R0", string(estimates.R0_est_Ohm), "Ohm", "processed data trend", "Average resistance estimate used to anchor the virtual cell resistance spread", "dataset"};
end

parameterAudit = cell2table(rows, 'VariableNames', ...
    {'parameter_name', 'value', 'unit', 'source', 'justification', 'provenance'});
end
