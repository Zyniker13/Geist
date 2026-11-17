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
Sources/MUCore/Sim/Boids.swift                                                                                                127                 8    93.70%          32                 0   100.00%         267                 2    99.25%           0                 0         -
Sources/MUCore/Sim/Energy.swift                                                                                                58                 2    96.55%          16                 1    93.75%         182                 9    95.05%           0                 0         -
Sources/MUCore/Sim/Falcon.swift                                                                                                72                 5    93.06%          11                 1    90.91%         179                 9    94.97%           0                 0         -
Sources/MUCore/Sim/GameState.swift                                                                                             38                 0   100.00%          26                 0   100.00%         182                 0   100.00%           0                 0         -
Sources/MUCore/Sim/LeaderPath.swift                                                                                            17                 0   100.00%           7                 0   100.00%          46                 0   100.00%           0                 0         -
Sources/MUCore/Sim/Reducer.swift                                                                                               92                10    89.13%          12                 2    83.33%         240                 9    96.25%           0                 0         -
Sources/MUCore/Sim/Roost.swift                                                                                                 65                 5    92.31%          12                 1    91.67%         119                13    89.08%           0                 0         -
Sources/MUCore/Sim/SpatialHash.swift                                                                                           14                 0   100.00%           6                 0   100.00%          41                 0   100.00%           0                 0         -
TOTAL                                                                                                                        1243               114    90.83%         626                63    89.94%        3257               146    95.52%           0                 0         -
```
