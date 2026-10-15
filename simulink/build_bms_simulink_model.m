function modelName = build_bms_simulink_model()
%BUILD_BMS_SIMULINK_MODEL Create a discrete-time Simulink BMS architecture.
% The generated model is still simplified relative to the MATLAB scenario
% runner, but the major supervisory subsystems now contain executable
% internal logic instead of empty passthrough ports.

cfg = bms_load_cfg();
modelName = "BMS_4S_UAV_Scaffold";

try
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end

    modelFile = fullfile(cfg.paths.projectRoot, modelName + ".slx");
    if exist(modelFile, "file")
        delete(modelFile);
    end

    new_system(modelName);
    open_system(modelName);
    set_param(modelName, "StopTime", num2str(cfg.sim.stopTime_s));
    set_param(modelName, "Solver", "FixedStepDiscrete");
    set_param(modelName, "FixedStep", num2str(cfg.sim.dt_s));

    topBlocks = {
        "simulink/Sources/Constant", "Charge_Enable", [30 80 90 110]
        "simulink/Sources/Constant", "Ambient_Temp", [30 140 90 170]
        "simulink/Ports & Subsystems/Subsystem", "CC_CV Charger Controller", [150 35 355 145]
        "simulink/Ports & Subsystems/Subsystem", "SoC Estimator", [150 190 355 285]
        "simulink/Ports & Subsystems/Subsystem", "Passive Balancing Logic", [150 330 355 430]
        "simulink/Ports & Subsystems/Subsystem", "Thermal Model", [150 475 355 580]
        "simulink/Ports & Subsystems/Subsystem", "Protection Logic", [705 195 910 285]
        "simulink/Ports & Subsystems/Subsystem", "Data Logging", [980 255 1210 455]
        "simulink/Math Operations/Sum", "Pack Voltage Sum", [620 55 650 155]
        "simulink/Signal Routing/Mux", "Cell Voltage Mux", [590 185 610 285]
        "simulink/Signal Routing/Mux", "Cell SoC Mux", [590 315 610 415]
        "simulink/Signal Routing/Mux", "Cell Temp Mux", [590 455 610 555]
        "simulink/Math Operations/MinMax", "Cell Voltage Max", [620 175 670 215]
        "simulink/Discrete/Unit Delay", "Pack Voltage Memory", [700 60 760 90]
        "simulink/Discrete/Unit Delay", "Max Cell Voltage Memory", [700 110 760 140]
        "simulink/Discrete/Unit Delay", "Max Temp Memory", [700 330 760 360]
        "simulink/Math Operations/Product", "Charge Current Gate", [405 70 455 100]
        "simulink/Discrete/Unit Delay", "Protection Memory", [700 390 760 420]
        "simulink/Signal Routing/Mux", "Charge Current Vector Mux", [470 610 490 710]
        "simulink/Signal Routing/Demux", "Balance Enable Demux", [405 330 435 430]
        "simulink/Signal Routing/Demux", "SoC Vector Demux", [405 205 435 305]
        "simulink/Signal Routing/Demux", "Temp Vector Demux", [405 480 435 580]
        };

    for idx = 1:size(topBlocks, 1)
        add_block(topBlocks{idx, 1}, modelName + "/" + topBlocks{idx, 2}, "Position", topBlocks{idx, 3});
    end

    set_param(modelName + "/Charge_Enable", "Value", "1");
    set_param(modelName + "/Ambient_Temp", "Value", num2str(cfg.thermal.ambient_C));
    set_param(modelName + "/Pack Voltage Sum", "Inputs", "++++");
    set_param(modelName + "/Cell Voltage Mux", "Inputs", "4");
    set_param(modelName + "/Cell SoC Mux", "Inputs", "4");
    set_param(modelName + "/Cell Temp Mux", "Inputs", "4");
    set_param(modelName + "/Cell Voltage Max", "Function", "max");
    set_param(modelName + "/Pack Voltage Memory", "InitialCondition", num2str(cfg.pack.nominalPackVoltage_V));
    set_param(modelName + "/Max Cell Voltage Memory", "InitialCondition", num2str(cfg.pack.nominalCellVoltage_V));
    set_param(modelName + "/Max Temp Memory", "InitialCondition", num2str(max(cfg.cells.initialTemp_C)));
    set_param(modelName + "/Protection Memory", "InitialCondition", "1");
    set_param(modelName + "/Charge Current Vector Mux", "Inputs", "4");
    set_param(modelName + "/Balance Enable Demux", "Outputs", "4");
    set_param(modelName + "/SoC Vector Demux", "Outputs", "4");
    set_param(modelName + "/Temp Vector Demux", "Outputs", "4");

    for cellIdx = 1:cfg.pack.numCells
        y = 40 + (cellIdx - 1) * 125;
        blockName = "Cell_" + cellIdx + "_ECM";
        add_block("simulink/Ports & Subsystems/Subsystem", modelName + "/" + blockName, ...
            "Position", [470 y 560 y + 85]);
        local_build_cell_subsystem(modelName + "/" + blockName, cfg, cellIdx);
    end

    local_build_charger_controller(modelName + "/CC_CV Charger Controller", cfg);
    local_build_soc_estimator(modelName + "/SoC Estimator", cfg);
    local_build_passive_balancing_logic(modelName + "/Passive Balancing Logic", cfg);
    local_build_thermal_model(modelName + "/Thermal Model", cfg);
    local_build_protection_logic(modelName + "/Protection Logic", cfg);
    local_build_data_logging(modelName + "/Data Logging");

    add_line(modelName, "Charge_Enable/1", "CC_CV Charger Controller/1");
    add_line(modelName, "Pack Voltage Sum/1", "Pack Voltage Memory/1");
    add_line(modelName, "Pack Voltage Memory/1", "CC_CV Charger Controller/2");
    add_line(modelName, "Cell Voltage Mux/1", "Cell Voltage Max/1");
    add_line(modelName, "Cell Voltage Max/1", "Max Cell Voltage Memory/1");
    add_line(modelName, "Max Cell Voltage Memory/1", "CC_CV Charger Controller/3");
    add_line(modelName, "Max Temp Memory/1", "CC_CV Charger Controller/4");

    add_line(modelName, "CC_CV Charger Controller/1", "Charge Current Gate/1");
    add_line(modelName, "Protection Memory/1", "Charge Current Gate/2");
    add_line(modelName, "Protection Logic/1", "Protection Memory/1");

    add_line(modelName, "Cell Voltage Mux/1", "SoC Estimator/2");
    add_line(modelName, "SoC Estimator/1", "SoC Vector Demux/1");

    add_line(modelName, "Cell Voltage Mux/1", "Passive Balancing Logic/1");
    add_line(modelName, "Protection Memory/1", "Passive Balancing Logic/2");
    add_line(modelName, "Passive Balancing Logic/1", "Balance Enable Demux/1");

    add_line(modelName, "Passive Balancing Logic/2", "Thermal Model/2");
    add_line(modelName, "Ambient_Temp/1", "Thermal Model/3");
    add_line(modelName, "Thermal Model/1", "Temp Vector Demux/1");
    add_line(modelName, "Thermal Model/2", "Max Temp Memory/1");

    for cellIdx = 1:cfg.pack.numCells
        add_line(modelName, "Charge Current Gate/1", "Charge Current Vector Mux/" + cellIdx);
    end
    add_line(modelName, "Charge Current Vector Mux/1", "SoC Estimator/1");
    add_line(modelName, "Charge Current Vector Mux/1", "Thermal Model/1");

    add_line(modelName, "Cell Voltage Mux/1", "Protection Logic/1");
    add_line(modelName, "Thermal Model/1", "Protection Logic/2");
    add_line(modelName, "Pack Voltage Sum/1", "Protection Logic/3");

    for cellIdx = 1:cfg.pack.numCells
        blockName = "Cell_" + cellIdx + "_ECM";
        add_line(modelName, "Charge Current Gate/1", blockName + "/1");
        add_line(modelName, "Balance Enable Demux/" + cellIdx, blockName + "/2");
        add_line(modelName, blockName + "/1", "Pack Voltage Sum/" + cellIdx);
        add_line(modelName, blockName + "/1", "Cell Voltage Mux/" + cellIdx);
        add_line(modelName, "SoC Vector Demux/" + cellIdx, "Cell SoC Mux/" + cellIdx);
        add_line(modelName, "Temp Vector Demux/" + cellIdx, "Cell Temp Mux/" + cellIdx);
    end

    add_line(modelName, "Cell Voltage Mux/1", "Data Logging/1");
    add_line(modelName, "Pack Voltage Sum/1", "Data Logging/2");
    add_line(modelName, "Charge Current Gate/1", "Data Logging/3");
    add_line(modelName, "SoC Estimator/1", "Data Logging/4");
    add_line(modelName, "Thermal Model/1", "Data Logging/5");
    add_line(modelName, "Passive Balancing Logic/1", "Data Logging/6");
    add_line(modelName, "Passive Balancing Logic/2", "Data Logging/7");
    add_line(modelName, "Protection Logic/1", "Data Logging/8");

    save_system(modelName);
    fprintf("Simulink model created: %s\n", modelFile);
    fprintf("Subsystem internals now include charger, SoC, balancing, thermal, protection, and logging logic.\n");
catch ME
    fprintf("Simulink build warning: %s\n", ME.message);
    fprintf("Open simulink/Simulink_Build_Guide.md for the architecture and fallback manual instructions.\n");
end
end

function local_build_cell_subsystem(pathName, cfg, cellIdx)
local_clear_subsystem(pathName);

add_block("simulink/Ports & Subsystems/In1", pathName + "/charge_current_cmd", "Position", [30 35 60 49]);
add_block("simulink/Ports & Subsystems/In1", pathName + "/balance_enable", "Position", [30 85 60 99]);
add_block("simulink/Ports & Subsystems/Out1", pathName + "/cell_voltage", "Position", [340 35 370 49]);
add_block("simulink/Ports & Subsystems/Out1", pathName + "/cell_soc", "Position", [340 90 370 104]);
add_block("simulink/Ports & Subsystems/Out1", pathName + "/cell_temp", "Position", [340 145 370 159]);

add_block("simulink/Sources/Constant", pathName + "/Initial_SoC", ...
    "Value", num2str(cfg.cells.initialSoC(cellIdx)), "Position", [230 85 290 105]);
add_block("simulink/Sources/Constant", pathName + "/Initial_Temp", ...
    "Value", num2str(cfg.cells.initialTemp_C(cellIdx)), "Position", [230 140 290 160]);
add_block("simulink/Sources/Constant", pathName + "/Nominal_Voltage", ...
    "Value", num2str(cfg.pack.nominalCellVoltage_V), "Position", [90 20 145 40]);
add_block("simulink/Math Operations/Gain", pathName + "/IR_Drop", ...
    "Gain", num2str(cfg.cells.R0_Ohm(cellIdx)), "Position", [95 55 145 85]);
add_block("simulink/Sinks/Terminator", pathName + "/balance_unused", ...
    "Position", [95 110 115 130]);
add_block("simulink/Math Operations/Sum", pathName + "/Voltage_Estimate", ...
    "Inputs", "++", "Position", [225 35 255 70]);

add_line(pathName, "charge_current_cmd/1", "IR_Drop/1");
add_line(pathName, "balance_enable/1", "balance_unused/1");
add_line(pathName, "Nominal_Voltage/1", "Voltage_Estimate/1");
add_line(pathName, "IR_Drop/1", "Voltage_Estimate/2");
add_line(pathName, "Voltage_Estimate/1", "cell_voltage/1");
add_line(pathName, "Initial_SoC/1", "cell_soc/1");
add_line(pathName, "Initial_Temp/1", "cell_temp/1");
end

function local_build_charger_controller(pathName, cfg)
local_clear_subsystem(pathName);

local_named_inport(pathName, "enable", [30 25 60 39]);
local_named_inport(pathName, "pack_voltage_meas", [30 65 60 79]);
local_named_inport(pathName, "max_cell_voltage_meas", [30 105 60 119]);
local_named_inport(pathName, "max_temp_meas", [30 145 60 159]);
local_named_outport(pathName, "charge_current_cmd", [425 55 455 69]);
local_named_outport(pathName, "mode_code", [425 125 455 139]);

add_block("simulink/Sources/Constant", pathName + "/I_CC", ...
    "Value", num2str(cfg.charger.ccCurrent_A), "Position", [85 10 135 30]);
add_block("simulink/Sources/Constant", pathName + "/V_CV", ...
    "Value", num2str(cfg.charger.cvTargetPackVoltage_V), "Position", [85 50 135 70]);
add_block("simulink/Sources/Constant", pathName + "/CV_Entry_Pack", ...
    "Value", num2str(cfg.charger.cvTargetPackVoltage_V - 0.02), "Position", [85 90 145 110]);
add_block("simulink/Sources/Constant", pathName + "/CV_Entry_Cell", ...
    "Value", num2str(cfg.charger.cvEntryCellVoltage_V), "Position", [85 130 145 150]);
add_block("simulink/Sources/Constant", pathName + "/Max_Cell_Limit", ...
    "Value", num2str(cfg.pack.maxCellVoltage_V), "Position", [85 170 145 190]);
add_block("simulink/Sources/Constant", pathName + "/Max_Temp_Limit", ...
    "Value", num2str(cfg.thermal.protectionTemperature_C), "Position", [85 210 145 230]);
add_block("simulink/Sources/Constant", pathName + "/Mode_CC", ...
    "Value", "1", "Position", [310 95 350 115]);
add_block("simulink/Sources/Constant", pathName + "/Mode_CV", ...
    "Value", "2", "Position", [310 125 350 145]);
add_block("simulink/Sources/Constant", pathName + "/Mode_Stop", ...
    "Value", "0", "Position", [310 155 350 175]);

add_block("simulink/Math Operations/Sum", pathName + "/Voltage_Error", ...
    "Inputs", "+-", "Position", [165 52 195 78]);
add_block("simulink/Math Operations/Gain", pathName + "/Kp_CV", ...
    "Gain", num2str(cfg.charger.currentKp_A_per_V), "Position", [220 50 270 80]);
add_block("simulink/Discontinuities/Saturation", pathName + "/Current_Saturation", ...
    "UpperLimit", num2str(cfg.charger.ccCurrent_A), "LowerLimit", "0", "Position", [295 50 340 80]);
add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/Pack_CV_Compare", ...
    "Operator", ">=", "Position", [175 90 215 120]);
add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/Cell_CV_Compare", ...
    "Operator", ">=", "Position", [175 125 215 155]);
add_block("simulink/Logic and Bit Operations/Logical Operator", pathName + "/CV_Mode_Or", ...
    "Operator", "OR", "Inputs", "2", "Position", [245 105 275 145]);
add_block("simulink/Signal Routing/Switch", pathName + "/CC_CV_Switch", ...
    "Threshold", "0.5", "Criteria", "u2 >= Threshold", "Position", [365 48 405 82]);
add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/OverV_Compare", ...
    "Operator", ">=", "Position", [175 165 215 195]);
add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/OverT_Compare", ...
    "Operator", ">=", "Position", [175 205 215 235]);
add_block("simulink/Logic and Bit Operations/Logical Operator", pathName + "/Trip_Or", ...
    "Operator", "OR", "Inputs", "2", "Position", [245 185 275 225]);
add_block("simulink/Logic and Bit Operations/Logical Operator", pathName + "/Trip_Not", ...
    "Operator", "NOT", "Position", [300 190 330 220]);
add_block("simulink/Math Operations/Product", pathName + "/Enable_Gate", ...
    "Inputs", "***", "Position", [365 98 405 132]);
add_block("simulink/Signal Routing/Switch", pathName + "/Mode_CC_CV_Switch", ...
    "Threshold", "0.5", "Criteria", "u2 >= Threshold", "Position", [365 118 405 148]);
add_block("simulink/Signal Routing/Switch", pathName + "/Mode_Stop_Switch", ...
    "Threshold", "0.5", "Criteria", "u2 >= Threshold", "Position", [365 152 405 182]);

add_line(pathName, "V_CV/1", "Voltage_Error/1");
add_line(pathName, "pack_voltage_meas/1", "Voltage_Error/2");
add_line(pathName, "Voltage_Error/1", "Kp_CV/1");
add_line(pathName, "Kp_CV/1", "Current_Saturation/1");

add_line(pathName, "pack_voltage_meas/1", "Pack_CV_Compare/1");
add_line(pathName, "CV_Entry_Pack/1", "Pack_CV_Compare/2");
add_line(pathName, "max_cell_voltage_meas/1", "Cell_CV_Compare/1");
add_line(pathName, "CV_Entry_Cell/1", "Cell_CV_Compare/2");
add_line(pathName, "Pack_CV_Compare/1", "CV_Mode_Or/1");
add_line(pathName, "Cell_CV_Compare/1", "CV_Mode_Or/2");

add_line(pathName, "Current_Saturation/1", "CC_CV_Switch/1");
add_line(pathName, "CV_Mode_Or/1", "CC_CV_Switch/2");
add_line(pathName, "I_CC/1", "CC_CV_Switch/3");

add_line(pathName, "max_cell_voltage_meas/1", "OverV_Compare/1");
add_line(pathName, "Max_Cell_Limit/1", "OverV_Compare/2");
add_line(pathName, "max_temp_meas/1", "OverT_Compare/1");
add_line(pathName, "Max_Temp_Limit/1", "OverT_Compare/2");
add_line(pathName, "OverV_Compare/1", "Trip_Or/1");
add_line(pathName, "OverT_Compare/1", "Trip_Or/2");
add_line(pathName, "Trip_Or/1", "Trip_Not/1");

add_line(pathName, "CC_CV_Switch/1", "Enable_Gate/1");
add_line(pathName, "enable/1", "Enable_Gate/2");
add_line(pathName, "Trip_Not/1", "Enable_Gate/3");
add_line(pathName, "Enable_Gate/1", "charge_current_cmd/1");

add_line(pathName, "Mode_CV/1", "Mode_CC_CV_Switch/1");
add_line(pathName, "CV_Mode_Or/1", "Mode_CC_CV_Switch/2");
add_line(pathName, "Mode_CC/1", "Mode_CC_CV_Switch/3");
add_line(pathName, "Mode_Stop/1", "Mode_Stop_Switch/1");
add_line(pathName, "Trip_Not/1", "Mode_Stop_Switch/2");
add_line(pathName, "Mode_CC_CV_Switch/1", "Mode_Stop_Switch/3");
add_line(pathName, "Mode_Stop_Switch/1", "mode_code/1");
end

function local_build_soc_estimator(pathName, cfg)
local_clear_subsystem(pathName);

local_named_inport(pathName, "cell_current_vector", [30 50 60 64]);
local_named_inport(pathName, "cell_voltage_vector", [30 110 60 124]);
local_named_outport(pathName, "soc_vector", [545 80 575 94]);

add_block("simulink/Signal Routing/Demux", pathName + "/Current_Demux", ...
    "Outputs", num2str(cfg.pack.numCells), "Position", [85 35 115 145]);
add_block("simulink/Signal Routing/Demux", pathName + "/Voltage_Demux", ...
    "Outputs", num2str(cfg.pack.numCells), "Position", [85 170 115 280]);
add_block("simulink/Signal Routing/Mux", pathName + "/SoC_Mux", ...
    "Inputs", num2str(cfg.pack.numCells), "Position", [500 45 520 155]);

add_line(pathName, "cell_current_vector/1", "Current_Demux/1");
add_line(pathName, "cell_voltage_vector/1", "Voltage_Demux/1");

for cellIdx = 1:cfg.pack.numCells
    x0 = 150;
    y0 = 20 + (cellIdx - 1) * 60;

    gainName = "Coulomb_Gain_" + cellIdx;
    integName = "SoC_Integrator_" + cellIdx;
    absName = "Current_Abs_" + cellIdx;
    thresholdName = "Current_Threshold_" + cellIdx;
    compareName = "Low_Current_Compare_" + cellIdx;
    biasName = "Voltage_Bias_" + cellIdx;
    gainVoltName = "Voltage_To_SoC_" + cellIdx;
    satName = "Voltage_Saturation_" + cellIdx;
    gainCoulombName = "Blend_Coulomb_" + cellIdx;
    gainVoltageName = "Blend_Voltage_" + cellIdx;
    sumName = "Blend_Sum_" + cellIdx;
    switchName = "Correction_Switch_" + cellIdx;

    add_block("simulink/Math Operations/Gain", pathName + "/" + gainName, ...
        "Gain", num2str(cfg.cells.eta_charge(cellIdx) / (3600 * cfg.cells.capacity_Ah(cellIdx))), ...
        "Position", [145 y0 + 5 205 y0 + 25]);
    add_block("simulink/Discrete/Discrete-Time Integrator", pathName + "/" + integName, ...
        "gainval", "1", "InitialCondition", num2str(cfg.cells.initialSoC(cellIdx)), ...
        "SampleTime", num2str(cfg.sim.dt_s), "Position", [235 y0 285 y0 + 30]);
    add_block("simulink/Math Operations/Abs", pathName + "/" + absName, ...
        "Position", [145 y0 + 32 175 y0 + 52]);
    add_block("simulink/Sources/Constant", pathName + "/" + thresholdName, ...
        "Value", num2str(cfg.socCorrection.currentThreshold_A), "Position", [205 y0 + 32 245 y0 + 52]);
    add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/" + compareName, ...
        "Operator", "<=", "Position", [275 y0 + 32 315 y0 + 52]);
    add_block("simulink/Math Operations/Bias", pathName + "/" + biasName, ...
        "Bias", "-3.0", "Position", [145 y0 + 62 185 y0 + 82]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + gainVoltName, ...
        "Gain", num2str(1 / 1.2), "Position", [205 y0 + 62 255 y0 + 82]);
    add_block("simulink/Discontinuities/Saturation", pathName + "/" + satName, ...
        "UpperLimit", "1", "LowerLimit", "0", "Position", [285 y0 + 60 325 y0 + 84]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + gainCoulombName, ...
        "Gain", num2str(1 - cfg.socCorrection.blendGain), "Position", [345 y0 395 y0 + 20]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + gainVoltageName, ...
        "Gain", num2str(cfg.socCorrection.blendGain), "Position", [345 y0 + 60 395 y0 + 80]);
    add_block("simulink/Math Operations/Sum", pathName + "/" + sumName, ...
        "Inputs", "++", "Position", [425 y0 + 24 455 y0 + 56]);
    add_block("simulink/Signal Routing/Switch", pathName + "/" + switchName, ...
        "Threshold", "0.5", "Criteria", "u2 >= Threshold", "Position", [470 y0 + 14 500 y0 + 46]);

    add_line(pathName, "Current_Demux/" + cellIdx, gainName + "/1");
    add_line(pathName, "Current_Demux/" + cellIdx, absName + "/1");
    add_line(pathName, gainName + "/1", integName + "/1");
    add_line(pathName, absName + "/1", compareName + "/1");
    add_line(pathName, thresholdName + "/1", compareName + "/2");
    add_line(pathName, "Voltage_Demux/" + cellIdx, biasName + "/1");
    add_line(pathName, biasName + "/1", gainVoltName + "/1");
    add_line(pathName, gainVoltName + "/1", satName + "/1");
    add_line(pathName, integName + "/1", gainCoulombName + "/1");
    add_line(pathName, satName + "/1", gainVoltageName + "/1");
    add_line(pathName, gainCoulombName + "/1", sumName + "/1");
    add_line(pathName, gainVoltageName + "/1", sumName + "/2");
    add_line(pathName, sumName + "/1", switchName + "/1");
    add_line(pathName, compareName + "/1", switchName + "/2");
    add_line(pathName, integName + "/1", switchName + "/3");
    add_line(pathName, switchName + "/1", "SoC_Mux/" + cellIdx);
end

add_line(pathName, "SoC_Mux/1", "soc_vector/1");
end

function local_build_passive_balancing_logic(pathName, cfg)
local_clear_subsystem(pathName);

startVoltage_V = cfg.balance.improved.startVoltage_V;
threshold_V = cfg.balance.improved.threshold_V;
resistor_Ohm = cfg.balance.improved.resistor_Ohm;
maxBleed_A = cfg.balance.maxBleedCurrent_A;

local_named_inport(pathName, "cell_voltage_vector", [30 55 60 69]);
local_named_inport(pathName, "charge_enable", [30 110 60 124]);
local_named_outport(pathName, "balance_enable_vector", [530 55 560 69]);
local_named_outport(pathName, "bleed_current_vector", [530 130 560 144]);

add_block("simulink/Signal Routing/Demux", pathName + "/Voltage_Demux", ...
    "Outputs", num2str(cfg.pack.numCells), "Position", [90 45 120 155]);
add_block("simulink/Math Operations/MinMax", pathName + "/Min_Cell_Voltage", ...
    "Function", "min", "Position", [90 170 140 205]);
add_block("simulink/Signal Routing/Mux", pathName + "/Balance_Mux", ...
    "Inputs", num2str(cfg.pack.numCells), "Position", [485 45 505 155]);
add_block("simulink/Signal Routing/Mux", pathName + "/Bleed_Mux", ...
    "Inputs", num2str(cfg.pack.numCells), "Position", [485 170 505 280]);

add_line(pathName, "cell_voltage_vector/1", "Voltage_Demux/1");
add_line(pathName, "cell_voltage_vector/1", "Min_Cell_Voltage/1");

for cellIdx = 1:cfg.pack.numCells
    y0 = 20 + (cellIdx - 1) * 65;
    deltaName = "DeltaV_" + cellIdx;
    startName = "Start_Threshold_" + cellIdx;
    deltaThreshName = "Delta_Threshold_" + cellIdx;
    startCompareName = "Start_Compare_" + cellIdx;
    deltaCompareName = "Delta_Compare_" + cellIdx;
    gateName = "Gate_And_" + cellIdx;
    enableName = "Enable_And_" + cellIdx;
    bleedGainName = "Bleed_Gain_" + cellIdx;
    bleedSatName = "Bleed_Sat_" + cellIdx;
    bleedGateName = "Bleed_Gate_" + cellIdx;

    add_block("simulink/Math Operations/Sum", pathName + "/" + deltaName, ...
        "Inputs", "+-", "Position", [155 y0 + 10 185 y0 + 35]);
    add_block("simulink/Sources/Constant", pathName + "/" + startName, ...
        "Value", num2str(startVoltage_V), "Position", [155 y0 + 40 195 y0 + 60]);
    add_block("simulink/Sources/Constant", pathName + "/" + deltaThreshName, ...
        "Value", num2str(threshold_V), "Position", [215 y0 + 40 255 y0 + 60]);
    add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/" + startCompareName, ...
        "Operator", ">=", "Position", [205 y0 + 5 245 y0 + 30]);
    add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/" + deltaCompareName, ...
        "Operator", ">=", "Position", [265 y0 + 5 305 y0 + 30]);
    add_block("simulink/Logic and Bit Operations/Logical Operator", pathName + "/" + gateName, ...
        "Operator", "AND", "Inputs", "2", "Position", [330 y0 + 5 360 y0 + 30]);
    add_block("simulink/Logic and Bit Operations/Logical Operator", pathName + "/" + enableName, ...
        "Operator", "AND", "Inputs", "2", "Position", [385 y0 + 5 415 y0 + 30]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + bleedGainName, ...
        "Gain", num2str(1 / resistor_Ohm), "Position", [205 y0 + 75 255 y0 + 95]);
    add_block("simulink/Discontinuities/Saturation", pathName + "/" + bleedSatName, ...
        "UpperLimit", num2str(maxBleed_A), "LowerLimit", "0", "Position", [285 y0 + 73 330 y0 + 97]);
    add_block("simulink/Math Operations/Product", pathName + "/" + bleedGateName, ...
        "Inputs", "**", "Position", [385 y0 + 70 420 y0 + 100]);

    add_line(pathName, "Voltage_Demux/" + cellIdx, deltaName + "/1");
    add_line(pathName, "Min_Cell_Voltage/1", deltaName + "/2");
    add_line(pathName, "Voltage_Demux/" + cellIdx, startCompareName + "/1");
    add_line(pathName, startName + "/1", startCompareName + "/2");
    add_line(pathName, deltaName + "/1", deltaCompareName + "/1");
    add_line(pathName, deltaThreshName + "/1", deltaCompareName + "/2");
    add_line(pathName, startCompareName + "/1", gateName + "/1");
    add_line(pathName, deltaCompareName + "/1", gateName + "/2");
    add_line(pathName, gateName + "/1", enableName + "/1");
    add_line(pathName, "charge_enable/1", enableName + "/2");
    add_line(pathName, "Voltage_Demux/" + cellIdx, bleedGainName + "/1");
    add_line(pathName, bleedGainName + "/1", bleedSatName + "/1");
    add_line(pathName, bleedSatName + "/1", bleedGateName + "/1");
    add_line(pathName, enableName + "/1", bleedGateName + "/2");
    add_line(pathName, enableName + "/1", "Balance_Mux/" + cellIdx);
    add_line(pathName, bleedGateName + "/1", "Bleed_Mux/" + cellIdx);
end

add_line(pathName, "Balance_Mux/1", "balance_enable_vector/1");
add_line(pathName, "Bleed_Mux/1", "bleed_current_vector/1");
end

function local_build_thermal_model(pathName, cfg)
local_clear_subsystem(pathName);

local_named_inport(pathName, "cell_current_vector", [30 50 60 64]);
local_named_inport(pathName, "bleed_current_vector", [30 110 60 124]);
local_named_inport(pathName, "ambient_temp", [30 170 60 184]);
local_named_outport(pathName, "temperature_vector", [565 70 595 84]);
local_named_outport(pathName, "max_temperature", [565 145 595 159]);

add_block("simulink/Signal Routing/Demux", pathName + "/Current_Demux", ...
    "Outputs", num2str(cfg.pack.numCells), "Position", [95 40 125 150]);
add_block("simulink/Signal Routing/Demux", pathName + "/Bleed_Demux", ...
    "Outputs", num2str(cfg.pack.numCells), "Position", [95 165 125 275]);
add_block("simulink/Signal Routing/Mux", pathName + "/Temp_Mux", ...
    "Inputs", num2str(cfg.pack.numCells), "Position", [515 45 535 155]);
add_block("simulink/Math Operations/MinMax", pathName + "/Temp_Max", ...
    "Function", "max", "Position", [515 170 555 205]);

add_line(pathName, "cell_current_vector/1", "Current_Demux/1");
add_line(pathName, "bleed_current_vector/1", "Bleed_Demux/1");

for cellIdx = 1:cfg.pack.numCells
    y0 = 15 + (cellIdx - 1) * 65;
    iSqName = "I_Square_" + cellIdx;
    jouleGainName = "Joule_Gain_" + cellIdx;
    bleedSqName = "Bleed_Square_" + cellIdx;
    bleedPowerName = "Bleed_Power_" + cellIdx;
    tempIntName = "Temp_Integrator_" + cellIdx;
    deltaTempName = "DeltaTemp_" + cellIdx;
    coolGainName = "Cooling_Gain_" + cellIdx;
    heatSumName = "Heat_Balance_" + cellIdx;
    cthGainName = "Cth_Gain_" + cellIdx;

    add_block("simulink/Math Operations/Product", pathName + "/" + iSqName, ...
        "Inputs", "**", "Position", [155 y0 190 y0 + 25]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + jouleGainName, ...
        "Gain", num2str(cfg.cells.R0_Ohm(cellIdx)), "Position", [210 y0 255 y0 + 25]);
    add_block("simulink/Math Operations/Product", pathName + "/" + bleedSqName, ...
        "Inputs", "**", "Position", [155 y0 + 28 190 y0 + 53]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + bleedPowerName, ...
        "Gain", num2str(cfg.balance.improved.resistor_Ohm), "Position", [210 y0 + 28 255 y0 + 53]);
    add_block("simulink/Discrete/Discrete-Time Integrator", pathName + "/" + tempIntName, ...
        "gainval", "1", "InitialCondition", num2str(cfg.cells.initialTemp_C(cellIdx)), ...
        "SampleTime", num2str(cfg.sim.dt_s), "Position", [445 y0 + 10 495 y0 + 40]);
    add_block("simulink/Math Operations/Sum", pathName + "/" + deltaTempName, ...
        "Inputs", "+-", "Position", [270 y0 + 70 300 y0 + 95]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + coolGainName, ...
        "Gain", num2str(cfg.cells.hA_W_per_C(cellIdx)), "Position", [320 y0 + 70 365 y0 + 95]);
    add_block("simulink/Math Operations/Sum", pathName + "/" + heatSumName, ...
        "Inputs", "++-", "Position", [385 y0 + 18 415 y0 + 62]);
    add_block("simulink/Math Operations/Gain", pathName + "/" + cthGainName, ...
        "Gain", num2str(1 / cfg.cells.Cth_J_per_C(cellIdx)), "Position", [445 y0 + 58 495 y0 + 88]);

    add_line(pathName, "Current_Demux/" + cellIdx, iSqName + "/1");
    add_line(pathName, "Current_Demux/" + cellIdx, iSqName + "/2");
    add_line(pathName, iSqName + "/1", jouleGainName + "/1");
    add_line(pathName, "Bleed_Demux/" + cellIdx, bleedSqName + "/1");
    add_line(pathName, "Bleed_Demux/" + cellIdx, bleedSqName + "/2");
    add_line(pathName, bleedSqName + "/1", bleedPowerName + "/1");
    add_line(pathName, tempIntName + "/1", deltaTempName + "/1");
    add_line(pathName, "ambient_temp/1", deltaTempName + "/2");
    add_line(pathName, deltaTempName + "/1", coolGainName + "/1");
    add_line(pathName, jouleGainName + "/1", heatSumName + "/1");
    add_line(pathName, bleedPowerName + "/1", heatSumName + "/2");
    add_line(pathName, coolGainName + "/1", heatSumName + "/3");
    add_line(pathName, heatSumName + "/1", cthGainName + "/1");
    add_line(pathName, cthGainName + "/1", tempIntName + "/1");
    add_line(pathName, tempIntName + "/1", "Temp_Mux/" + cellIdx);
end

add_line(pathName, "Temp_Mux/1", "temperature_vector/1");
add_line(pathName, "Temp_Mux/1", "Temp_Max/1");
add_line(pathName, "Temp_Max/1", "max_temperature/1");
end

function local_build_protection_logic(pathName, cfg)
local_clear_subsystem(pathName);

local_named_inport(pathName, "cell_voltage_vector", [30 45 60 59]);
local_named_inport(pathName, "temperature_vector", [30 95 60 109]);
local_named_inport(pathName, "pack_voltage", [30 145 60 159]);
local_named_outport(pathName, "charge_enable_out", [350 95 380 109]);

add_block("simulink/Math Operations/MinMax", pathName + "/Max_Cell_Voltage", ...
    "Function", "max", "Position", [90 35 140 65]);
add_block("simulink/Math Operations/MinMax", pathName + "/Max_Temperature", ...
    "Function", "max", "Position", [90 85 140 115]);
add_block("simulink/Sources/Constant", pathName + "/Cell_Limit", ...
    "Value", num2str(cfg.pack.maxCellVoltage_V), "Position", [155 15 205 35]);
add_block("simulink/Sources/Constant", pathName + "/Temp_Limit", ...
    "Value", num2str(cfg.thermal.protectionTemperature_C), "Position", [155 65 205 85]);
add_block("simulink/Sources/Constant", pathName + "/Pack_Limit", ...
    "Value", num2str(cfg.pack.maxPackVoltage_V), "Position", [155 115 205 135]);
add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/Cell_Trip", ...
    "Operator", ">=", "Position", [220 20 260 45]);
add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/Temp_Trip", ...
    "Operator", ">=", "Position", [220 70 260 95]);
add_block("simulink/Logic and Bit Operations/Relational Operator", pathName + "/Pack_Trip", ...
    "Operator", ">=", "Position", [220 120 260 145]);
add_block("simulink/Logic and Bit Operations/Logical Operator", pathName + "/Trip_Or", ...
    "Operator", "OR", "Inputs", "3", "Position", [285 55 315 125]);
add_block("simulink/Logic and Bit Operations/Logical Operator", pathName + "/Enable_Not", ...
    "Operator", "NOT", "Position", [330 85 360 115]);

add_line(pathName, "cell_voltage_vector/1", "Max_Cell_Voltage/1");
add_line(pathName, "temperature_vector/1", "Max_Temperature/1");
add_line(pathName, "Max_Cell_Voltage/1", "Cell_Trip/1");
add_line(pathName, "Cell_Limit/1", "Cell_Trip/2");
add_line(pathName, "Max_Temperature/1", "Temp_Trip/1");
add_line(pathName, "Temp_Limit/1", "Temp_Trip/2");
add_line(pathName, "pack_voltage/1", "Pack_Trip/1");
add_line(pathName, "Pack_Limit/1", "Pack_Trip/2");
add_line(pathName, "Cell_Trip/1", "Trip_Or/1");
add_line(pathName, "Temp_Trip/1", "Trip_Or/2");
add_line(pathName, "Pack_Trip/1", "Trip_Or/3");
add_line(pathName, "Trip_Or/1", "Enable_Not/1");
add_line(pathName, "Enable_Not/1", "charge_enable_out/1");
end

function local_build_data_logging(pathName)
local_clear_subsystem(pathName);

inputNames = [
    "cell_voltage_vector"
    "pack_voltage"
    "charge_current"
    "soc_vector"
    "temperature_vector"
    "balance_enable_vector"
    "bleed_current_vector"
    "protection_flag"
    ];

workspaceNames = [
    "cellVoltagesSim"
    "packVoltageSim"
    "chargeCurrentSim"
    "socEstimateSim"
    "temperatureSim"
    "balanceSignalSim"
    "bleedCurrentSim"
    "protectionFlagSim"
    ];

for idx = 1:numel(inputNames)
    y = 25 + (idx - 1) * 35;
    inputBlock = char(inputNames(idx));
    logBlock = "Log_" + idx;

    add_block("simulink/Ports & Subsystems/In1", pathName + "/" + inputBlock, ...
        "Position", [30 y 60 y + 14]);

    add_block("simulink/Sinks/To Workspace", pathName + "/" + logBlock, ...
        "VariableName", char(workspaceNames(idx)), "SaveFormat", "Structure With Time", ...
        "Position", [135 y - 5 235 y + 19]);

    add_line(pathName, inputBlock + "/1", logBlock + "/1");
end
end

function local_named_inport(pathName, portName, position)
add_block("simulink/Ports & Subsystems/In1", pathName + "/" + portName, "Position", position);
end

function local_named_outport(pathName, portName, position)
add_block("simulink/Ports & Subsystems/Out1", pathName + "/" + portName, "Position", position);
end

function local_clear_subsystem(pathName)
blocks = find_system(pathName, "SearchDepth", 1, "Type", "Block");
lines = find_system(pathName, "FindAll", "on", "SearchDepth", 1, "Type", "line");
for idx = 1:numel(lines)
    delete_line(lines(idx));
end
for idx = 2:numel(blocks)
    delete_block(blocks{idx});
end
end
