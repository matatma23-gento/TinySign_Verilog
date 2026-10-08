#!/usr/bin/env python3
"""Record reproducible RTL test results; simulation never counts as a board run."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
FULL=['tb_montgomery_mul','tb_mod_arith','tb_point_ops','tb_scalar_mult',
      'tb_hmac','tb_rfc6979','tb_sha256_hash','tb_ecdsa_signer','tb_key_manager','tb_tinysign_core','tb_shared_engines',
      'tb_tinysign_de10nano','tb_selftest_uart','tb_board_selftest']
QUICK=['tb_montgomery_mul','tb_mod_arith','tb_point_ops','tb_hmac','tb_rfc6979',
       'tb_sha256_hash','tb_tinysign_de10nano','tb_selftest_uart']

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--quick',action='store_true',help='skip multi-million-cycle ECC/signing/selftest runs')
    ap.add_argument('--output',type=Path,default=ROOT/'reports'/'validation')
    args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    selected=QUICK if args.quick else FULL
    results={'source':'rtl_simulation','timestamp_utc':datetime.now(timezone.utc).isoformat(),
             'suite':'quick' if args.quick else 'full','hardware_status':'not_run',
             'sources_sha256':{},'tests':[],'not_run':[t for t in FULL if t not in selected]}
    for folder in ('rtl','tb','python','tests','scripts'):
        for path in sorted((ROOT/folder).rglob('*')):
            if path.is_file() and path.suffix in ('.v','.py','.sh'):
                results['sources_sha256'][str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    jobs=[('python_reference',[sys.executable,'-m','unittest','discover','-s','tests','-v']),
          ('python_vs_verilog_mod_arith',[sys.executable,'scripts/compare_mod_arith.py'])]
    jobs += [(test,['bash','scripts/run_rtl_tests.sh',test]) for test in selected]
    env=dict(os.environ,TRACE_DIR=str(out))
    manifest=out/'results.json'
    for name,command in jobs:
        log_path=out/(name+'.log')
        start=time.monotonic()
        record={'name':name,'command':command,'log':str(log_path),'status':'running'}
        results['tests'].append(record)
        manifest.write_text(json.dumps(results,indent=2)+'\n')
        print('Running',name,flush=True)
        with log_path.open('w') as log:
            try:
                completed=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
                code=completed.returncode
            except OSError as exc:
                log.write(str(exc)+'\n');code=127
        record.update(status='pass' if code==0 else 'fail',exit_code=code,
                      wall_seconds=round(time.monotonic()-start,3))
        manifest.write_text(json.dumps(results,indent=2)+'\n')
        print(name,record['status'],flush=True)
    rows=['# RTL validation results','',f"Suite: {results['suite']}. Source: simulation. Board: NOT RUN.",'',
          '| Test | Result | Wall time (s) |','|---|---|---:|']
    for test in results['tests']:
        rows.append(f"| {test['name']} | {test['status'].upper()} | {test['wall_seconds']} |")
    if results['not_run']: rows+=['','Not run in this invocation: '+', '.join(results['not_run'])+'.']
    rows+=['','Wall time is host simulation runtime, not FPGA latency. See per-test logs for cycle counts.']
    (out/'results.md').write_text('\n'.join(rows)+'\n')
    raise SystemExit(int(any(t['status']!='pass' for t in results['tests'])))

if __name__=='__main__': main()
