#!/usr/bin/env python3
"""Run structural checks or experimental Cyclone V mapping; never claim P&R."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--top',default='tinysign_core')
    ap.add_argument('--mode',choices=('check','cyclonev'),default='check')
    ap.add_argument('--output',type=Path,default=ROOT/'reports'/'yosys')
    args=ap.parse_args()
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',args.top):
        ap.error('invalid Verilog top module name')
    out=args.output.resolve()/f'{args.top}_{args.mode}'
    out.mkdir(parents=True,exist_ok=True)
    sources=sorted(ROOT.glob('rtl/*/*.v'))
    # Relative paths are deliberately rooted at ROOT; no user shell interpolation.
    lines=['read_verilog '+' '.join(chr(34)+str(p)+chr(34) for p in sources),
           f'hierarchy -check -top {args.top}']
    if args.mode=='check':
        lines+=['proc','opt','check -assert']
    else:
        lines+=[f'synth_intel_alm -family cyclonev -top {args.top} -noiopad -noclkbuf',
                'check -assert']
    def quoted(p):
        return '"'+str(p).replace('\\','\\\\').replace('"','\\"')+'"'
    lines += ['tee -o stat.json stat -json', 'write_json netlist.json']
    script=out/'run.ys'; script.write_text('\n'.join(lines)+'\n')
    exe=os.environ.get('YOSYS','yosys')
    metadata={'top':args.top,'mode':args.mode,'timestamp_utc':datetime.now(timezone.utc).isoformat(),
              'sources_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
              'implementation':'not_run','hardware':'not_run'}
    try:
        version=subprocess.run([exe,'-V'],text=True,capture_output=True,check=True).stdout.strip()
        metadata['tool']=version
        with (out/'console.log').open('w') as log:
            result=subprocess.run([exe,'-Q','-T','-s',str(script)],cwd=out,stdout=log,stderr=subprocess.STDOUT)
        metadata['status']='pass' if result.returncode==0 else 'fail'
        metadata['exit_code']=result.returncode
    except (OSError,subprocess.CalledProcessError) as e:
        metadata.update(status='unavailable',error=str(e),exit_code=2)
    (out/'result.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(f"Yosys {args.mode}: {metadata['status']}; {out}")
    if metadata['exit_code']:
        log=out/'console.log'
        if log.exists(): print('\n'.join(log.read_text(errors='replace').splitlines()[-20:]))
    raise SystemExit(metadata['exit_code'])

if __name__=='__main__': main()
