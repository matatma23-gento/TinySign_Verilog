#!/usr/bin/env python3
"""Compare P-256 modular add/sub/inverse RTL against Python integer oracles."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import random
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
P256_P = int("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF", 16)
P256_N = int("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551", 16)
MODULI = (("p", P256_P), ("n", P256_N))
OPS = ((0, "mod_add"), (1, "mod_sub"), (2, "mod_inv"))
SEED = 0x54494E595349474E


def build_vectors():
    rng = random.Random(SEED)
    vectors = []

    def add(op, name, modulus_id, modulus, a, b=0, invalid=False):
        if op == 0:
            expected = (a + b) % modulus
        elif op == 1:
            expected = (a - b) % modulus
        else:
            expected = None if invalid else pow(a, -1, modulus)
        vectors.append({
            "index": len(vectors), "operation": name,
            "operation_code": op, "modulus_name": modulus_id,
            "modulus": modulus, "a": a, "b": b,
            "expected_result": expected, "expected_error": invalid,
        })

    for modulus_id, modulus in MODULI:
        edge = (0, 1, 2, modulus - 2, modulus - 1)
        for op, name in OPS[:2]:
            for a in edge:
                for b in edge:
                    add(op, name, modulus_id, modulus, a, b)
            for _ in range(32):
                add(op, name, modulus_id, modulus,
                    rng.randrange(modulus), rng.randrange(modulus))

        # Zero has no inverse and must be rejected; the remaining cases include
        # one, two, modulus-2, modulus-1, and deterministic random residues.
        inverse_values = [0, 1, 2, modulus - 2, modulus - 1]
        inverse_values.extend(rng.randrange(1, modulus) for _ in range(8))
        for value in inverse_values:
            add(2, "mod_inv", modulus_id, modulus, value, invalid=(value == 0))
    return vectors


def run():
    out = ROOT / "reports" / "arithmetic_comparison"
    out.mkdir(parents=True, exist_ok=True)
    vector_path = out / "vectors.txt"
    sim_path = out / "tb_python_mod_arith.vvp"
    log_path = out / "icarus.log"
    json_path = out / "results.json"
    report_path = out / "report.md"
    vectors = build_vectors()
    vector_path.write_text("".join(
        f"{v['index']} {v['operation_code']} {0 if v['modulus_name']=='p' else 1} "
        f"{v['modulus']:064x} {v['a']:064x} {v['b']:064x} "
        f"{(v['expected_result'] or 0):064x} {int(v['expected_error'])}\n"
        for v in vectors), encoding="ascii")

    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    results = {
        "status": "BLOCKED", "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "python": sys.version.split()[0], "random_seed": hex(SEED),
        "moduli": {name: f"{value:064x}" for name, value in MODULI},
        "vector_count": len(vectors), "vectors": [],
        "artifacts": {"vectors": str(vector_path), "icarus_log": str(log_path)},
        "source_sha256": {},
    }
    log = [f"Python: {sys.version.split()[0]}", f"Icarus: {iverilog or 'not found'}",
           f"vvp: {vvp or 'not found'}", f"Vector file: {vector_path}", ""]
    if not iverilog or not vvp:
        log.append("ERROR: iverilog and vvp must be on PATH")
        log_path.write_text("\n".join(log) + "\n", encoding="utf-8")
        results["status"] = "BLOCKED"
        results["error"] = "iverilog or vvp was not found on PATH"
        json_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        report_path.write_text("# Python-versus-Verilog modular arithmetic\n\n**BLOCKED:** Icarus Verilog tools were not found.\n", encoding="utf-8")
        print("Python-versus-Verilog modular arithmetic: BLOCKED (Icarus unavailable)")
        return 2

    for tool in (iverilog, vvp):
        version = subprocess.run([tool, "-V"], cwd=ROOT, text=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log.append(f"$ {tool} -V\n{version.stdout.strip()}\n")

    sources = [ROOT / "rtl" / "arithmetic" / file for file in
               ("mod_add.v", "mod_sub.v", "mod_mul.v", "montgomery_mul.v", "mod_inv.v")]
    sources.append(ROOT / "tb" / "tb_python_mod_arith.v")
    compile_command = [iverilog, "-g2001", "-Wall", "-s", "tb_python_mod_arith",
                       "-o", str(sim_path), *(str(p) for p in sources)]
    log.append("$ " + " ".join(compile_command))
    started = time.monotonic()
    compiled = subprocess.run(compile_command, cwd=ROOT, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    results["compile_seconds"] = round(time.monotonic() - started, 3)
    log.append(compiled.stdout)
    if compiled.returncode:
        results["status"] = "FAIL"
        results["error"] = f"Icarus compile exited {compiled.returncode}"
        log_path.write_text("\n".join(log) + "\n", encoding="utf-8")
        json_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        report_path.write_text("# Python-versus-Verilog modular arithmetic\n\n**FAIL:** Icarus compilation failed. See `icarus.log`.\n", encoding="utf-8")
        print("Python-versus-Verilog modular arithmetic: FAIL (Icarus compilation)")
        return 1

    sim_command = [vvp, "-N", str(sim_path), f"+vectors={vector_path}"]
    log.append("$ " + " ".join(sim_command))
    started = time.monotonic()
    simulated = subprocess.run(sim_command, cwd=ROOT, text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    results["simulation_seconds"] = round(time.monotonic() - started, 3)
    log.append(simulated.stdout)

    records = []
    for line in simulated.stdout.splitlines():
        if not line.startswith("RESULT|"):
            continue
        fields = line.split("|")
        if len(fields) != 13:
            continue
        _, idx, op, mid, mod, a, b, expected, actual, exp_err, act_err, done, cycles = fields
        records.append({
            "index": int(idx), "operation": OPS[int(op)][1],
            "modulus_name": "p" if int(mid) == 0 else "n",
            "modulus": mod.lower(), "a": a.lower(), "b": b.lower(),
            "expected_result": None if int(exp_err) else expected.lower(),
            "rtl_result": actual.lower(),
            "expected_error": bool(int(exp_err)), "rtl_error": bool(int(act_err)),
            "rtl_done": bool(int(done)), "cycles": int(cycles),
        })
    for record in records:
        expected_error = record["expected_error"]
        record["exact_match"] = (
            record["rtl_error"] == expected_error and
            (not expected_error and record["rtl_done"] and
             record["rtl_result"] == record["expected_result"] or
             expected_error and not record["rtl_done"])
        )
    all_records_present = len(records) == len(vectors)
    all_matched = all_records_present and all(r["exact_match"] for r in records)
    results.update({
        "status": "PASS" if simulated.returncode == 0 and all_matched else "FAIL",
        "simulator_exit_code": simulated.returncode,
        "records_found": len(records), "all_exact_matches": all_matched,
        "vectors": records,
    })
    for source in [*sources, ROOT / "scripts" / "compare_mod_arith.py"]:
        results["source_sha256"][str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
    log_path.write_text("\n".join(log) + "\n", encoding="utf-8")
    json_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")

    counts = {}
    for name, _ in OPS:
        op_name = OPS[name][1]
        group = [r for r in records if r["operation"] == op_name]
        counts[op_name] = {"vectors": len(group), "passed": sum(r["exact_match"] for r in group)}
    rows = ["# Python-versus-Verilog modular arithmetic", "",
            f"**Status: {results['status']}** — {len(records)}/{len(vectors)} vectors emitted; "
            f"{sum(r['exact_match'] for r in records)}/{len(vectors)} exact matches.", "",
            f"Icarus: `{subprocess.run([iverilog, '-V'], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.splitlines()[0]}`; mode `-g2001 -Wall`.",
            f"Deterministic random seed: `{hex(SEED)}`.", "",
            "| Module | p vectors | n vectors | Exact Python/RTL matches |", "|---|---:|---:|---:|"]
    for _, op_name in OPS:
        p_count = sum(r["operation"] == op_name and r["modulus_name"] == "p" and r["exact_match"] for r in records)
        n_count = sum(r["operation"] == op_name and r["modulus_name"] == "n" and r["exact_match"] for r in records)
        p_total = sum(r["operation"] == op_name and r["modulus_name"] == "p" for r in records)
        n_total = sum(r["operation"] == op_name and r["modulus_name"] == "n" for r in records)
        rows.append(f"| `{op_name}` | {p_count}/{p_total} | {n_count}/{n_total} | {p_count+n_count}/{p_total+n_total} |")
    rows += ["", "Each JSON vector records Python’s expected value, the RTL value, error/done status, exact-match flag, and cycle count.",
             "Artifacts: [`results.json`](results.json), [`icarus.log`](icarus.log), [`vectors.txt`](vectors.txt)."]
    report_path.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"Python-versus-Verilog modular arithmetic: {results['status']} "
          f"({sum(r['exact_match'] for r in records)}/{len(vectors)} exact matches)")
    return 0 if results["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(run())
