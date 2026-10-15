# Reproducibility and source recovery

This repository was curated from a recovered diploma project in October 2026. Source files were reconstructed from recorded file contents and successful editing operations. Simulation figures were recovered from a surviving archive.

## Included evidence

- MATLAB source for the original simulation workflow and Simulink builder.
- Previously generated CSV summaries and plots, preserved in `results/`.
- Research discussion of the charging scenarios and their limitations.

## Known gaps

- Original raw measurements and processed `.mat` files are missing.
- Generated `.slx` models are missing.
- The original Git history is unavailable.

MATLAB simulations and Simulink execution have not been verified after recovery. Static file/reference checks do not establish numerical reproducibility. Archived results must be treated as historical outputs until the original inputs are restored and the pipeline is rerun.

## Publication cleanup

The curated copy contains the MATLAB/Simulink study, archived results and research documentation. Recovery logs, document drafts, old numbered script variants and incomplete third-party dataset code are excluded. The executable `stepXX_...` scripts remain the research pipeline entry points. Original source calculations were not changed during publication cleanup.

Full recovered files and recovery evidence remain outside this repository in the local workspace.
