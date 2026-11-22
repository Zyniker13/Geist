# MUCore coverage (llvm-cov over the Debug test run)

Gate G1 requires MUCore coverage >= 90%. The gate metric is the
line-coverage TOTAL below (Lines / Missed Lines / Cover columns:
total, missed, percent). Columns per row: regions, functions, lines.

```
Sources/MUCore/Foundation/Fixed.swift                                                                                          57                 9    84.21%          19                 4    78.95%         105                11    89.52%           0                 0         -
Sources/MUCore/Foundation/IntTrig.swift                                                                                         9                 2    77.78%           7                 2    71.43%          28                 6    78.57%           0                 0         -
Sources/MUCore/Foundation/SeededRNG.swift                                                                                      34                 3    91.18%          16                 2    87.50%          86                 4    95.35%           0                 0         -
Sources/MUCore/Replay.swift                                                                                                    26                 2    92.31%          12                 2    83.33%         105                 5    95.24%           0                 0         -
Sources/MUCore/Sim/Bird.swift                                                                                                   7                 2    71.43%           7                 2    71.43%          40                 6    85.00%           0                 0         -
Sources/MUCore/Sim/Boids.swift                                                                                                157                 7    95.54%          38                 0   100.00%         360                 5    98.61%           0                 0         -
Sources/MUCore/Sim/Energy.swift                                                                                                72                 1    98.61%          16                 1    93.75%         211                 9    95.73%           0                 0         -
Sources/MUCore/Sim/Falcon.swift                                                                                                98                 6    93.88%          23                 3    86.96%         296                10    96.62%           0                 0         -
Sources/MUCore/Sim/GameState.swift                                                                                             58                 2    96.55%          38                 2    94.74%         265                12    95.47%           0                 0         -
Sources/MUCore/Sim/LeaderPath.swift                                                                                            17                 0   100.00%           7                 0   100.00%          46                 0   100.00%           0                 0         -
Sources/MUCore/Sim/Reducer.swift                                                                                              106                10    90.57%          15                 2    86.67%         306                10    96.73%           0                 0         -
Sources/MUCore/Sim/Roost.swift                                                                                                 84                 1    98.81%          13                 1    92.31%         160                 7    95.62%           0                 0         -
Sources/MUCore/Sim/SpatialHash.swift                                                                                           14                 0   100.00%           6                 0   100.00%          41                 0   100.00%           0                 0         -
TOTAL                                                                                                                        1932               185    90.42%        1074               129    87.99%        5256               226    95.70%           0                 0         -
```

## P5 coverage (gate G5, 2026-11-22, 1ca4af6)

MUCore from `make coverage` (Debug test run); MUMeta and MUAI from
per-package `swift test --enable-code-coverage` + llvm-cov reports on the
same tree. Gate thresholds (_CONVENTIONS §testing): Core >= 90%, AI >= 75%,
Meta >= 75%, overall >= 60% — all pass.

| Package | Line metric source | Lines | Missed | Cover | Threshold |
| --- | --- | --- | --- | --- | --- |
| MUCore | `make coverage` TOTAL | 5256 | 226 | 95.70% | >= 90% ✓ |
| MUAI | llvm-cov TOTAL | 5518 | 1158 | 79.01% | >= 75% ✓ |
| MUMeta | llvm-cov sum of its four sources | 235 | 43 | 81.7% | >= 75% ✓ |
| Overall (sum of the above) | | 11009 | 1427 | 87.0% | >= 60% ✓ |

MUMeta per-source (regions/functions/lines columns elided to lines):
Achievements 84/24 = 71.43%, Campaign 32/3 = 90.62%, Daily 73/16 =
78.08%, Region+Daily 46/0 = 100.00%.
