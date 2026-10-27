import sys
import numpy as np
from netCDF4 import Dataset

fn = sys.argv[1]
mem = sys.argv[2]

f = Dataset(fn, "r+")
for v in ["T", "QVAPOR"]:
    if v in f.variables:
        x = f.variables[v][:]
        # damp anomalies toward zero mean state
        x = 0.7 * x
        f.variables[v][:] = x

for v in ["PH"]:
    if v in f.variables:
        x = f.variables[v][:]
        # reduce gravity-wave spikes
        x = np.clip(x, -15000, 15000)
        f.variables[v][:] = x

f.close()
print("Damping applied to member", mem)

