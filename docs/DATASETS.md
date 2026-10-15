# Dataset setup

The original measurement files are not included. Download datasets from their original providers, retain their attribution and usage terms, and place them locally before attempting to reproduce the research pipeline.

| Input | Preferred local folder | Expected content |
| --- | --- | --- |
| NASA PCoE battery aging data | `data/raw/nasa/` | Original battery-cycle `.mat` files |
| Oxford Battery Degradation Dataset 1 | `data/raw/oxford/` | `Oxford_Battery_Degradation_Dataset_1.mat` and `ExampleDC_C1.mat` |
| CALCE, optional | `data/raw/calce/` | Data compatible with the generic importer |
| Stanford/MATR, optional | `data/raw/stanford/` | Actual cycle `.mat` data, not just a loader script |

Paths are relative to the repository root. Setup creates these folders automatically. The legacy `datasets/` fallback paths remain supported by `functions/bms_default_cfg.m`, but neither raw nor processed data are tracked by Git.

The original study imported NASA and Oxford data. CALCE, Stanford/MATR cycle data and the Di Nisio UAV benchmark were not available in the recorded study. The recovered Stanford loader alone does not provide those measurements, so it is excluded from this curated repository.

Dataset attribution: the original study used NASA PCoE battery aging data and *Oxford Battery Degradation Dataset 1*, University of Oxford (2017), by Christoph Birkl and David Howey. The Oxford dataset documentation also requests citation of Christoph R. Birkl's 2017 thesis, *Diagnosis and Prognosis of Degradation in Lithium-Ion Batteries*. Preserve the citation and usage terms supplied with each downloaded dataset.

After restoring the inputs, run `scripts/run_full_diploma_project.m`. Inspect import messages and validation outputs: the presence of an output file does not by itself establish that the original data were used.
