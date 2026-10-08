#!/usr/bin/env python3
"""Capture a real self-test UART packet from the FPGA GPIO TX connection."""
import argparse
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time

try:
    import serial
except ImportError:  # Keep --help and packet parsing usable without pyserial.
    serial = None

PATTERN=re.compile(r'TS1,([PF]),([0-9A-F]{2}),([0-9A-F]{8}),([0-9A-F]{8})')

def parse_packet(line):
    match=PATTERN.fullmatch(line.strip())
    if not match:
        raise ValueError('invalid or incomplete TS1 report')
    verdict,code,provision,sign=match.groups()
    data={'passed':verdict=='P','failure_code':int(code,16),
          'provision_cycles':int(provision,16),'sign_cycles':int(sign,16)}
    if data['passed'] and (data['failure_code'] or not data['provision_cycles'] or not data['sign_cycles']):
        raise ValueError('inconsistent PASS packet')
    if not data['passed'] and not data['failure_code']:
        raise ValueError('FAIL packet has no failure code')
    return data

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--port',required=True,help='USB-to-TTL serial adapter, e.g. /dev/ttyUSB0')
    ap.add_argument('--timeout',type=float,default=30)
    ap.add_argument('--output',type=Path,default=Path('reports/hardware/board_test.json'))
    args=ap.parse_args()
    if args.timeout<=0: ap.error('timeout must be positive')
    if serial is None:
        raise SystemExit('pyserial is required for hardware capture: python3 -m pip install pyserial')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    result={'source':'hardware_uart','board':'DE10-Nano','clock_hz':50000000,
            'timestamp_utc':datetime.now(timezone.utc).isoformat(),'status':'not_run'}
    log=[]
    try:
        with serial.Serial(args.port,115200,timeout=min(1,args.timeout)) as port:
            print('Listening. Press KEY0 on the programmed board to run the self-test.',flush=True)
            deadline=time.monotonic()+args.timeout
            while time.monotonic()<deadline:
                line=port.readline().decode('ascii',errors='replace').strip()
                if not line: continue
                log.append(line)
                if line.startswith('TS1,'):
                    result.update(parse_packet(line))
                    result['status']='pass' if result['passed'] else 'fail'
                    for op in ('provision','sign'):
                        result[op+'_us']=result[op+'_cycles']/50.0
                    break
            else:
                raise TimeoutError('no complete self-test report before timeout')
    except (OSError,ValueError,TimeoutError,serial.SerialException) as exc:
        result.update(status='error',error=str(exc))
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    args.output.with_suffix('.uart.log').write_text('\n'.join(log)+'\n')
    # Rewrite even on failure so a previous successful CSV cannot look current.
    fields=['source','board','timestamp_utc','clock_hz','status','failure_code',
            'provision_cycles','sign_cycles','provision_us','sign_us']
    with args.output.with_suffix('.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore')
        writer.writeheader();writer.writerow(result)
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['status']=='pass' else 1)

if __name__=='__main__': main()
