import os
import sys

variant = os.environ.get("VARIANT", "?")
print("executable:", sys.executable, "base_prefix:", sys.base_prefix)
results = {}
try:
    import tkinter

    results["import"] = "ok"
except Exception as e:  # noqa: BLE001
    results["import"] = f"FAIL {type(e).__name__}: {e}"
else:
    try:
        results["tcl"] = "ok " + tkinter.Tcl().eval("info library")
    except Exception as e:  # noqa: BLE001
        results["tcl"] = f"FAIL {type(e).__name__}: {e}"
    try:
        root = tkinter.Tk()
        root.update()
        results["tk"] = "ok " + root.tk.eval("info patchlevel")
        root.destroy()
    except Exception as e:  # noqa: BLE001
        results["tk"] = f"FAIL {type(e).__name__}: {e}"
for key, value in results.items():
    line = value.replace("\n", " ")
    print(f"::notice title={variant} {key}::{line}")

if any(v.startswith("FAIL") for v in results.values()):
    sys.exit(1)
