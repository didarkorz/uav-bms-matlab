# Simulink Build Guide

Use this guide if `build_bms_simulink_model.m` needs manual adjustment on your MATLAB release.
The current builder now creates internal logic for the charger, SoC estimator,
passive balancing, thermal model, protection logic, and workspace logging.
This guide remains useful as a fallback reference and for manual refinement.

## Top-level blocks

Create these subsystems and signal blocks:

1. `CC_CV Charger Controller`
2. `Cell_1_ECM`
3. `Cell_2_ECM`
4. `Cell_3_ECM`
5. `Cell_4_ECM`
6. `SoC Estimator`
7. `Passive Balancing Logic`
8. `Thermal Model`
9. `Protection Logic`
10. `Data Logging`
11. `Pack Voltage Sum` using `simulink/Math Operations/Sum`
12. `Cell Voltage Mux` using `simulink/Signal Routing/Mux`
13. `Cell SoC Mux`
14. `Cell Temp Mux`
15. `Charge_Enable` constant
16. `Ambient_Temp` constant
17. `Cell Voltage Max`
18. `Pack Voltage Memory`
19. `Max Cell Voltage Memory`
20. `Max Temp Memory`
21. `Charge Current Gate`
22. `Protection Memory`
23. `Balance Enable Demux`
24. `SoC Vector Demux`
25. `Temp Vector Demux`

## Signal flow

1. `Charge_Enable` -> `CC_CV Charger Controller`
2. `CC_CV Charger Controller/charge_current_cmd` -> each `Cell_i_ECM/charge_current_cmd`
3. Each `Cell_i_ECM/cell_voltage` -> `Pack Voltage Sum` and `Cell Voltage Mux`
4. Each `Cell_i_ECM/cell_soc` -> `Cell SoC Mux`
5. Each `Cell_i_ECM/cell_temp` -> `Cell Temp Mux`
6. `Cell Voltage Mux` -> `SoC Estimator`, `Passive Balancing Logic`, `Protection Logic`, `Data Logging`
7. `Passive Balancing Logic/bleed_current_vector` -> `Thermal Model`
8. `Cell Temp Mux` -> `Protection Logic` and `Data Logging`
9. `Pack Voltage Sum` -> `Protection Logic`
10. `CC_CV Charger Controller/charge_current_cmd` -> `Data Logging`
11. `Passive Balancing Logic/balance_enable_vector` -> `Data Logging`
12. `Protection Logic/charge_enable_out` -> `Protection Memory`
13. `CC_CV Charger Controller/charge_current_cmd` -> `Charge Current Gate`
14. `Protection Memory` -> `Charge Current Gate`
15. `Charge Current Gate` -> cell current path, SoC estimator, thermal model, and data logging
16. `SoC Estimator/soc_vector` -> `SoC Vector Demux` -> `Cell SoC Mux`
17. `Thermal Model/temperature_vector` -> `Temp Vector Demux` -> `Cell Temp Mux`
18. `Cell Voltage Mux` -> `Cell Voltage Max` -> `Max Cell Voltage Memory` -> charger controller
19. `Pack Voltage Sum` -> `Pack Voltage Memory` -> charger controller
20. `Thermal Model/max_temperature` -> `Max Temp Memory` -> charger controller

The one-sample memory blocks intentionally break direct algebraic loops so the
charger operates as a discrete supervisor using the previous simulation step's
measurements.

## Cell ECM internals

Inside each `Cell_i_ECM` subsystem:

1. Inports:
   - `charge_current_cmd`
   - `balance_enable`
2. Outports:
   - `cell_voltage`
   - `cell_soc`
   - `cell_temp`
3. Current generated version:
   - simplified `Nominal_Voltage + I*R0` voltage estimate
   - constant initial SoC output placeholder
   - constant initial temperature output placeholder
4. Recommended next refinement:
   - `Unit Delay` for `SOC(k-1)`
   - `1-D Lookup Table` for `OCV(SOC)` or `2-D Lookup Table` for `OCV(SOC,T)`
   - optional discrete RC branch for `V_RC`
   - dynamic thermal and SoC states inside each cell block

## Charger controller

Recommended blocks:

1. `Constant` for `I_CC = 2.5 A`
2. `Constant` for `V_CV = 16.8 V`
3. `Relational Operator` to switch from CC to CV
4. `Sum` for `V_CV - V_pack`
5. `Gain` for proportional taper gain
6. `Saturation` from `0` to `2.5`
7. `Switch` for CC/CV mode output
8. `Relational Operator` for current cutoff at `0.25 A`
9. `Relational Operator` blocks for overvoltage and overtemperature stop
10. `Product` block to gate current with enable and protection flag

## Passive balancing logic

For each cell:

1. Compute `V_i - min(V_cells)`
2. Compare against threshold:
   - basic: `0.015 V`
   - improved: `0.010 V`
3. Require cell voltage above start threshold:
   - basic: `4.10 V`
   - improved: `4.00 V`
4. Compute `I_bal = V_i / R_bal`
   - basic: `R_bal = 33 Ohm`
   - improved: `R_bal = 18 Ohm`
5. Limit bleed current to about `0.25 A`

The generated builder currently implements the improved balancing thresholds by
default: `V_start = 4.00 V`, `DeltaV_threshold = 0.010 V`, `R_bal = 18 Ohm`.

## Thermal model

Per cell:

1. Use `Product` block for `I_cell^2`
2. Multiply by `R0`
3. Add balancing power `P_bal`
4. Subtract cooling `hA*(T-Tamb)`
5. Integrate with `1/Cth`

The generated builder estimates balancing heating from `I_bal^2 * R_bal`,
which is a practical supervision-level approximation when bleed current is
already available as a signal.

Suggested parameters:

- `Cth = [175 168 180 165] J/C`
- `hA = [0.78 0.72 0.81 0.69] W/C`
- `Tamb = 25 C`

## Protection logic

Use comparators for:

1. `max(V_cell) >= 4.20 V`
2. `max(T_cell) >= 48 C`
3. Optional `V_pack >= 16.8 V`

If any trip is true, force charge current command to zero and log the stop reason.
In the generated builder, the protection decision is applied through a
one-sample memory block before it gates the current command. This avoids an
algebraic loop at the top level.

## Data logging

Use `To Workspace` or `Signal Logging` for:

1. `cell_voltage_vector`
2. `pack_voltage`
3. `charge_current_cmd`
4. `soc_vector`
5. `temperature_vector`
6. `balance_enable_vector`
7. `bleed_current_vector`
8. `protection_flags`

Save format recommendation: `Structure With Time`.
The current builder writes the following workspace variables:

1. `cellVoltagesSim`
2. `packVoltageSim`
3. `chargeCurrentSim`
4. `socEstimateSim`
5. `temperatureSim`
6. `balanceSignalSim`
7. `bleedCurrentSim`
8. `protectionFlagSim`
