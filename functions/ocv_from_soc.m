function ocv_V = ocv_from_soc(soc)
%OCV_FROM_SOC Approximate LiPo open-circuit voltage from state of charge.
% The curve is intentionally smooth and monotonic so it behaves well in both
% MATLAB scripts and Simulink function blocks.

soc = min(max(soc, 0), 1);
ocv_V = 3.0 ...
    + 0.78 .* soc ...
    + 0.26 .* soc.^2 ...
    + 0.16 .* soc.^3;

ocv_V = min(max(ocv_V, 3.0), 4.2);
end
