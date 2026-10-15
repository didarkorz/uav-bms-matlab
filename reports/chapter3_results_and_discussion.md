# Chapter 3 - Results and Discussion

## 3.1 Introduction
This chapter presents the simulation results of the Battery Management System developed for charging a 4S lithium-polymer battery pack in UAV applications. The purpose of the analysis is to evaluate how cell mismatch affects the charging process and to determine whether passive balancing and improved supervisory control can reduce voltage mismatch, improve SoC uniformity, and prevent unsafe charge termination.

The results in this chapter are obtained from the MATLAB-based scenario simulation model. The Simulink model is used as a block-diagram representation of the BMS architecture, while the quantitative scenario comparison is based on the MATLAB implementation. Three charging scenarios are evaluated:

1. Scenario 1 - No balancing
2. Scenario 2 - Basic passive balancing
3. Scenario 3 - Improved BMS with optimized passive balancing and adaptive current reduction

The main evaluation indicators are final cell-voltage imbalance, SoC spread, maximum temperature, charging time, balancing energy, overvoltage occurrence, and charge termination reason.

## 3.2 Figures and Tables Used in This Chapter
The following figures should be inserted in Chapter 3. These figures are already generated in the `results` folder.

1. `cell_voltages_vs_time.png`
Caption: Cell voltages during charging for the simulated 4S LiPo battery pack.

2. `pack_voltage_and_current.png`
Caption: Pack voltage and charging current profile during CC-CV charging.

3. `soc_vs_time.png`
Caption: Estimated State of Charge of each cell during charging.

4. `temperature_vs_time.png`
Caption: Cell temperature response during the charging process.

5. `balancing_activation.png`
Caption: Passive balancing activation signals for the four cells.

6. `final_voltage_imbalance_comparison.png`
Caption: Final cell-voltage imbalance comparison across the three scenarios.

7. `final_soc_spread_comparison.png`
Caption: Final SoC spread comparison across the three scenarios.

8. `model_vs_measured_voltage.png`
Caption: Comparison between measured and simulated voltage for the validation profile.

The main numerical result table is based on `scenario_comparison_summary.csv`.

## 3.3 Scenario Comparison Summary
Table 3.1 summarizes the key results obtained from the three simulation scenarios.

Table 3.1 - Summary of simulation results

| Metric | No balancing | Basic passive balancing | Improved BMS |
|---|---:|---:|---:|
| Status | FAIL | FAIL | PASS |
| Termination reason | Predicted overvoltage | Predicted overvoltage | Current cutoff |
| CC duration, s | 3287 | 3337 | 7114 |
| CV duration, s | 121 | 128 | 2190 |
| Total charging time, s | 3408 | 3465 | 9304 |
| Final pack voltage, V | 16.6206 | 16.6340 | 16.7881 |
| Maximum cell voltage, V | 4.2002 | 4.2001 | 4.2000 |
| Final voltage imbalance, V | 0.0993 | 0.0903 | 0.0096 |
| Final SoC spread, % | 7.138 | 6.684 | 0.838 |
| Maximum temperature, degC | 27 | 27 | 27 |
| Balancing energy, Wh | 0 | 0.2195 | 2.7488 |
| Overvoltage predicted | Yes | Yes | No |
| Ended by current cutoff | No | No | Yes |
| Imbalance derating applied | No | No | Yes |

The comparison shows that the baseline and basic balancing cases both fail because the charging process is stopped by predicted overvoltage before the cells become sufficiently equalized. The improved BMS case passes the target criteria because it reaches the current cutoff condition while maintaining low voltage imbalance, low SoC spread, and safe temperature.

## 3.4 Scenario 1 - Charging Without Balancing
In the first scenario, the 4S battery pack is charged using the CC-CV charging algorithm without any cell balancing mechanism. The purpose of this case is to show the effect of natural cell mismatch during charging.

The cells start with different initial SoC values and slightly different electrical parameters. During charging, these differences cause the cell voltages to diverge. The highest-voltage cell reaches the upper voltage region earlier than the others, while the remaining cells still have lower terminal voltages and lower SoC. This behavior is visible in the cell-voltage curve and is confirmed by the final numerical values.

At the end of the no-balancing scenario, the final cell voltages are:

`[4.1327, 4.2002, 4.1009, 4.1869] V`

The final voltage imbalance is:

`0.0993 V`

The final SoC values are:

`[0.8914, 0.9386, 0.8672, 0.9221]`

This corresponds to a final SoC spread of:

`7.138 %`

The charging process stops after 3408 s because overvoltage is predicted. This means that one cell reaches the safe voltage limit before the other cells are fully charged. As a result, the battery pack is not fully utilized. This scenario confirms the main problem of multicell charging: without balancing, the weakest or highest-voltage cell limits the usable charge of the entire series pack.

## 3.5 Scenario 2 - Basic Passive Balancing
The second scenario introduces passive balancing with conservative activation settings. In this case, balancing begins only when a cell voltage exceeds approximately 4.10 V and its voltage is at least 0.015 V higher than the lowest cell. The balancing resistance is 33 Ohm, which limits the bleed current.

Compared with the no-balancing case, the basic balancing strategy slightly improves the final voltage distribution. However, the improvement is not sufficient to prevent overvoltage. The reason is that balancing begins relatively late, when the cell mismatch has already become significant near the top-of-charge region. Because the balancing current is limited, the higher-voltage cells cannot be discharged enough before one of them reaches the upper voltage limit.

At the end of the basic balancing scenario, the final cell voltages are:

`[4.1368, 4.2001, 4.1099, 4.1871] V`

The final voltage imbalance is:

`0.0903 V`

The final SoC values are:

`[0.8975, 0.9419, 0.8751, 0.9259]`

The final SoC spread is:

`6.684 %`

The balancing energy dissipated is approximately:

`0.2195 Wh`

Although balancing is active in this case, the final mismatch remains high. The charging process stops after 3465 s due to predicted overvoltage. Therefore, the basic passive balancing configuration provides only limited improvement and does not satisfy the project target.

## 3.6 Scenario 3 - Improved BMS
The third scenario represents the improved BMS configuration. In this case, passive balancing begins earlier, at approximately 4.00 V, with a smaller voltage-difference threshold of 0.010 V. The balancing resistance is reduced to 18 Ohm, allowing stronger bleed current. In addition, the charging current is adaptively reduced when voltage imbalance becomes too large.

This strategy gives the BMS more time to reduce cell mismatch before any individual cell reaches the maximum voltage limit. The earlier balancing action prevents the highest-voltage cells from moving too far ahead of the lower-voltage cells. The adaptive current reduction further improves the result by slowing the charging process when the pack is imbalanced, giving balancing more time to act.

At the end of the improved BMS scenario, the final cell voltages are:

`[4.1993, 4.1998, 4.1902, 4.1989] V`

The final voltage imbalance is:

`0.0096 V`

The final SoC values are:

`[0.9947, 0.9961, 0.9877, 0.9931]`

The final SoC spread is:

`0.838 %`

The charging process finishes after 9304 s and terminates normally by current cutoff. The final pack voltage is 16.7881 V, which is close to the 16.8 V target for a 4S LiPo pack. The improved scenario therefore satisfies the project targets: voltage imbalance is below 0.020 V, SoC spread is below 2 %, no predicted overvoltage occurs, and charging ends by current cutoff.

The balancing energy dissipated in this case is approximately 2.7488 Wh. This is higher than in the basic balancing case, but it is expected because the improved controller performs more active balancing over a longer period. This represents the main trade-off of passive balancing: better equalization is achieved at the cost of additional energy dissipation as heat.

## 3.7 Cell Voltage Discussion
The cell-voltage results are the most important evidence for the effectiveness of the BMS strategy. In the baseline case, the difference between the highest and lowest cell voltage remains large at the end of the simulation. In the basic balancing case, the voltage spread decreases slightly, but not enough to prevent overvoltage. In the improved case, the four cell voltages converge much more closely near the end of charge.

The final voltage imbalance decreases from 0.0993 V in the no-balancing case to 0.0903 V in the basic passive balancing case. This is only a small improvement. In contrast, the improved BMS reduces the final imbalance to 0.0096 V. Compared with the basic balancing case, this is an improvement of approximately 89.4 %. Compared with the no-balancing case, the improvement is approximately 90.3 %.

This result confirms that passive balancing can be effective, but only when its activation threshold, voltage-difference threshold, and resistance value are selected appropriately.

## 3.8 SoC Distribution Discussion
The SoC results support the voltage-based findings. In the no-balancing case, the final SoC spread is 7.138 %, which means the cells do not reach the same charge state before the highest-voltage cell limits the process. The basic balancing case reduces the SoC spread slightly to 6.684 %, but this is still too high for uniform pack utilization.

The improved BMS reduces the final SoC spread to 0.838 %. This indicates that the cells finish charging in a much more balanced state. A lower SoC spread improves effective pack utilization because the cells are closer to the same energy state at the end of charging.

The SoC plot should therefore be discussed together with the cell-voltage plot. Voltage imbalance shows the immediate safety problem, while SoC spread shows the energy-utilization problem.

## 3.9 Charging Current and CC-CV Behavior
The pack-voltage and current plot demonstrates the CC-CV behavior of the charging process. In a normal CC-CV charging profile, the current is initially high during the constant-current stage. As the pack approaches the voltage limit, the controller enters the constant-voltage stage and the current decreases toward the cutoff threshold.

In the baseline and basic balancing scenarios, the charging process stops early due to predicted overvoltage. These cases do not achieve a clean current-cutoff termination. In the improved scenario, charging lasts longer because the controller reduces current to support balancing and avoid cell overvoltage. The charging process ends normally when the current reaches the cutoff condition.

The longer charging time in the improved case should not be interpreted as a weakness by itself. It is the result of safer and more controlled charging. The improved controller trades charging speed for better cell equalization and safer termination.

## 3.10 Balancing Activation Discussion
The balancing activation figure shows when each cell is selected for passive bleeding. In the no-balancing case, no balancing activity occurs. In the basic balancing case, balancing activates late and does not have enough time or strength to correct the mismatch. In the improved case, balancing begins earlier and remains active over a longer period, especially for the cells that reach higher voltages.

The comparison between balancing energy and final imbalance shows the main design trade-off. The basic balancing case dissipates only 0.2195 Wh but leaves a final voltage imbalance of 0.0903 V. The improved case dissipates 2.7488 Wh but reduces the final imbalance to 0.0096 V. Therefore, the improved case is less energy-efficient in the balancing circuit itself, but much more effective for safe and uniform charging.

For UAV battery charging, this trade-off can be acceptable because balancing is normally performed during charging on the ground, while the benefit is improved pack readiness and safer flight operation.

## 3.11 Thermal Response Discussion
The thermal response remains moderate in all scenarios. The maximum temperature reported in the scenario comparison is approximately 27 degC. This value is far below the selected thermal protection threshold and below the temperature region where thermal stress would dominate system behavior.

The moderate temperature response is explained by the selected charging current, simplified thermal parameters, and the fact that the simulation focuses on charging rather than high-current UAV discharge. The improved balancing case dissipates more balancing energy, but the resulting thermal increase remains small in the simulation.

Therefore, the thermal model does not dominate the final result in this study. However, including it is still important because it allows the BMS framework to monitor temperature and provides a basis for future studies with higher charging currents, more aggressive balancing, or realistic UAV load cycles.

## 3.12 Model Validation Discussion
The model validation was performed by replaying a measured current profile from the Oxford dataset through the single-cell equivalent-circuit model and comparing the simulated voltage with the measured voltage. The validation results are:

| Metric | Value |
|---|---:|
| Dataset | Oxford |
| Profile | ExampleDC_C1_dc |
| Number of points | 250 |
| RMSE | 0.1214 V |
| MAE | 0.0779 V |
| Maximum absolute error | 0.4496 V |
| R2 score | 0.0487 |

The validation results show that the model provides a reasonable system-level voltage trend, but it does not reproduce all transient details with high precision. The relatively low R2 value indicates that the model should not be claimed as a high-accuracy predictive electrochemical model.

This limitation is acceptable for the purpose of this work because the main objective is not exact cell-voltage prediction under all conditions. The objective is to compare BMS charging strategies under the same model assumptions. Since all scenarios use the same battery model structure and parameter set, the comparison between no balancing, basic balancing, and improved balancing remains meaningful.

The validation should therefore be interpreted as a plausibility check rather than full hardware validation.

## 3.13 Overall Discussion
The results answer the research questions defined in Chapter 1. The simulation shows that cell mismatch has a strong effect on multicell charging. Without balancing, one cell reaches the voltage limit earlier than the others, causing premature termination and leaving the pack underutilized. Basic passive balancing reduces the mismatch only slightly because it begins too late and uses a weaker bleed path.

The improved BMS performs better because it combines three features:

1. Earlier passive balancing activation
2. Lower balancing resistance and stronger bleed current
3. Adaptive current reduction when voltage imbalance increases

These features allow the pack to reach a much more uniform final state. The final voltage imbalance is reduced below 0.010 V, and the final SoC spread is reduced below 1 %. The improved scenario also avoids predicted overvoltage and terminates by current cutoff, which is the desired behavior for CC-CV charging.

The main disadvantage of the improved strategy is increased charging duration. The total charging time increases from approximately 3465 s in the basic balancing case to 9304 s in the improved case. This increase is caused by the more conservative current behavior and longer balancing activity. For UAV applications, this may be acceptable when safety and battery utilization are more important than minimum charging time.

The results also show that passive balancing has an inherent energy loss. The improved strategy dissipates more energy in the balancing resistors than the basic strategy. However, this energy loss is the cost of achieving better cell equalization with a simple and lightweight balancing method.

## 3.14 Limitations of the Results
Several limitations must be noted. First, the analysis is simulation-based and does not include hardware testing. Therefore, the results should be interpreted as system-level simulation evidence rather than experimental proof.

Second, the battery model is a first-order equivalent-circuit model. It is suitable for BMS-level analysis, but it does not include detailed electrochemical dynamics, aging mechanisms, or spatial thermal gradients.

Third, the validation results show only moderate agreement with measured voltage data. The model is useful for comparative analysis of control strategies, but it is not a high-precision predictive model.

Fourth, the Simulink implementation is used mainly as a supervisory architecture representation and simplified execution path. The primary quantitative conclusions are based on the MATLAB scenario simulation.

Finally, the thermal response remains mild in the current charging simulations. More demanding conditions, such as fast charging or UAV discharge load profiles, may produce stronger thermal effects and should be investigated in future work.

## 3.15 Chapter Summary
This chapter presented the results and discussion of the developed BMS simulation. Three charging scenarios were compared: no balancing, basic passive balancing, and improved BMS control. The no-balancing and basic balancing scenarios both failed because charging stopped due to predicted overvoltage before acceptable cell equalization was achieved.

The improved BMS scenario achieved the best result. It reduced the final voltage imbalance to 0.0096 V, reduced the final SoC spread to 0.838 %, avoided predicted overvoltage, and completed charging by current cutoff. The maximum temperature remained approximately 27 degC, indicating safe thermal behavior under the simulated conditions.

The results demonstrate that passive balancing can be effective for a 4S UAV LiPo battery pack when it is activated early enough and coordinated with charging-current supervision. The improved control strategy increases charging time and balancing energy dissipation, but it provides significantly better safety and charge uniformity.
