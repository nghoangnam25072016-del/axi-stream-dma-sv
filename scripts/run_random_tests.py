#!/usr/bin/env python3
"""
Multi-seed regression helper for the AXI stream DMA project.

Example:
  python3 scripts/run_random_tests.py --sim questa --count 20
"""

import argparse
import random
import subprocess
import sys
from pathlib import Path


def run_cmd(cmd, cwd):
    print("\n$ " + " ".join(cmd))
    proc = subprocess.run(cmd, cwd=cwd)
    return proc.returncode


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim", default="questa", choices=["questa", "vcs", "xcelium"])
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--waves", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    sim_dir = root / "sim"

    random.seed(0xD00D)
    seeds = [random.randint(1, 2**31 - 1) for _ in range(args.count)]

    failures = 0
    for idx, seed in enumerate(seeds):
        print(f"\n===== Regression {idx+1}/{len(seeds)} seed={seed} =====")
        cmd = [
            "make",
            f"SIM={args.sim}",
            "run",
            f"SEED={seed}",
            f"WAVES={1 if args.waves else 0}",
        ]
        rc = run_cmd(cmd, cwd=sim_dir)
        if rc != 0:
            failures += 1
            print(f"FAILED seed={seed}")
        else:
            print(f"PASSED seed={seed}")

    print("\n===== Regression summary =====")
    print(f"Total: {len(seeds)}  Passed: {len(seeds)-failures}  Failed: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
