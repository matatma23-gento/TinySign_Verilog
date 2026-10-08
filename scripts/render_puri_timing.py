#!/usr/bin/env python3
"""Render event-driven RTL control traces; never infer cryptographic results."""
from pathlib import Path
import argparse, csv, hashlib, json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--trace-dir', type=Path, default=ROOT/'reports/puri_sign/timing')
args = parser.parse_args()
out = args.trace_dir.resolve()
schema = json.loads((out/'signal_schema.json').read_text())
period = schema['clock_period_ns']
assert period == 40
# Event logging may observe multiple delta cycles. Keep settled values at each ns.
by_time = {}
with (out/'control_events.csv').open() as f:
    for row in csv.DictReader(f):
        row = {k:int(v) for k,v in row.items()}
        by_time[row['time_ns']] = row
rows = [by_time[t] for t in sorted(by_time)]
assert rows and rows[0]['time_ns'] <= 1
T = np.array([r['time_ns'] for r in rows], dtype=np.int64)
D = {k:np.array([r[k] for r in rows]) for k in rows[0]}
D['cmd_sign'] = (D['bus_write']==1)&(D['cmd']==4)
D['cmd_zeroize'] = (D['bus_write']==1)&(D['cmd']==5)
end = int(T[-1])+240

def segments(name):
    values=D[name]; starts=np.r_[0, np.flatnonzero(values[1:]!=values[:-1])+1]
    return [(int(T[i]),int(T[starts[j+1]]) if j+1<len(starts) else end,int(values[i]))
            for j,i in enumerate(starts)]

def high(name): return [(a,b) for a,b,v in segments(name) if v==1]

def rising(name): return [a for a,_,v in segments(name) if v==1]

p0,p1=high('provision_owner')[0]
s0,s1=high('sign_owner')[0]
z0=rising('zeroize')[0]
assert (s1-s0)//period == 7437840
assert (p1-p0)//period == 7303706
assert not np.any(D['provision_owner']&D['sign_owner'])
assert not np.any(D['error_latch'])
assert any(a<=s1<b and v==1 for a,b,v in segments('sign_valid'))
assert D['key_valid'][-1] == D['key_locked'][-1] == D['sign_valid'][-1] == 0
for name in ['scalar_done','inv_done','mul_done','sign_done','zeroize']:
    assert all(b-a==period for a,b in high(name)),name
scalar_end=next(b for a,b in high('scalar_busy') if s0<a<s1)

COL={'provision_owner':'#2563a5','sign_owner':'#13866e','nonce_busy':'#8655aa',
     'scalar_busy':'#2563a5','inv_busy':'#b16d18','mul_busy':'#bb4d46',
     'zeroize':'#bf3434','cmd_zeroize':'#bf3434','sign_valid':'#13866e',
     'clk_stimulus':'#73808a'}
LABEL={'core_busy':'core.busy','provision_owner':'owner: PROVISION',
       'sign_owner':'owner: SIGN','key_valid':'key_valid','key_locked':'key_locked',
       'nonce_busy':'RFC6979 busy','scalar_busy':'shared scalar busy',
       'inv_busy':'shared inverse busy','mul_busy':'shared multiply busy',
       'sign_valid':'sign_valid (latched)','clk_stimulus':'clk: 25 MHz',
       'cmd_sign':'bus: CMD_SIGN','cmd_zeroize':'bus: CMD_ZEROIZE',
       'sign_start':'sign_start','sign_done':'sign_done (pulse)',
       'done_latch':'done_latch','zeroize':'key_zeroize','scalar_start':'scalar_start',
       'scalar_done':'scalar_done','nonce_done':'nonce_done','add_busy':'mod_add busy'}
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.titlesize':12,
                     'svg.fonttype':'none','savefig.facecolor':'white'})

def values_at(name, ts):
    if name=='clk_stimulus': return (np.floor_divide(ts,20)%2).astype(int)
    return D[name][np.maximum(0,np.searchsorted(T,ts,side='right')-1)]

def waves(ax,names,lo,hi,origin=0,scale=1,label='Waktu (ns)'):
    for i,name in enumerate(names):
        base=len(names)-i-1
        if name=='clk_stimulus':
            inside=np.arange((lo//20+1)*20,hi,20)
        else: inside=T[(T>lo)&(T<hi)]
        ts=np.r_[lo,inside,hi].astype(np.int64)
        vals=values_at(name,ts)
        xx=(ts-origin)/scale; yy=base+0.18+0.60*vals
        color=COL.get(name,'#405568')
        ax.step(xx,yy,where='post',lw=1.5,color=color)
        ax.fill_between(xx,base+0.18,yy,step='post',color=color,alpha=0.09)
        ax.axhline(base+0.05,color='#e9edf0',lw=0.6)
    ax.set_yticks(np.arange(len(names))+0.48,[LABEL.get(n,n) for n in names[::-1]],fontsize=9)
    ax.set_ylim(-0.1,len(names)+0.12)
    ax.set_xlim((lo-origin)/scale,(hi-origin)/scale)
    ax.xaxis.set_major_locator(MaxNLocator(7))
    ax.grid(axis='x',color='#dce2e8',lw=0.6)
    ax.set_xlabel(label)
    ax.tick_params(axis='y',length=0,pad=8)
    for spine in ['top','right','left']:ax.spines[spine].set_visible(False)
    ax.spines['bottom'].set_color('#b8c3ce')

ART=[]
def save(fig,name):
    for ext in ['png','svg']:
        path=out/f'{name}.{ext}';fig.savefig(path,dpi=170,bbox_inches='tight');ART.append(path.name)
    plt.close(fig)

fig,ax=plt.subplots(figsize=(14,7.5))
fig.subplots_adjust(left=.19,right=.98,top=.79,bottom=.17)
names=['core_busy','provision_owner','sign_owner','key_valid','key_locked','nonce_busy',
       'scalar_busy','inv_busy','mul_busy','sign_valid','zeroize']
waves(ax,names,0,end,scale=1e6,label='Waktu simulasi (ms) — skala linear, tanpa pemotongan waktu')
ax.axvspan(p0/1e6,p1/1e6,color=COL['provision_owner'],alpha=.045)
ax.axvspan(s0/1e6,s1/1e6,color=COL['sign_owner'],alpha=.045)
for a,b,title,color in [(p0,p1,'PROVISION',COL['provision_owner']),(s0,s1,'SIGN',COL['sign_owner'])]:
    ax.text((a+b)/2/1e6,1.055,f'{title}: {(b-a)/1e6:.4f} ms\n{(b-a)//40:,} siklus'.replace(',','.'),
            transform=ax.get_xaxis_transform(),ha='center',fontsize=10,color=color)
fig.suptitle('PURI-Sign | Timing provisioning dan signing',x=.19,y=.98,ha='left',fontsize=18,fontweight='bold')
fig.text(.19,.925,'Simulasi RTL • P-256 d=1 • SHA-256("sample") • clk 25 MHz / 40 ns',fontsize=11,color='#55616d')
fig.text(.19,.07,'Mesin ECC yang sama dipakai bergantian. Pulsa 40 ns tidak diperlebar pada tampilan keseluruhan.\nSigning kedua di akhir trace dibatalkan oleh ZEROIZE; lihat diagram zoom untuk detail per siklus.',fontsize=10,color='#55616d')
save(fig,'01_overview')

fig,axes=plt.subplots(2,1,figsize=(14,11))
fig.subplots_adjust(left=.20,right=.98,top=.87,bottom=.12,hspace=.48)
names=['sign_owner','nonce_busy','nonce_done','scalar_start','scalar_busy','scalar_done',
       'inv_busy','mul_busy','add_busy','sign_done','sign_valid']
waves(axes[0],names,s0-80,s0+65000,origin=s0,scale=1000,label='Waktu sejak core menerima SIGN (µs)')
axes[0].set_title('A. Awal signing — nonce RFC6979 lalu peluncuran scalar',loc='left',pad=13)
waves(axes[1],names,scalar_end-400,s1+10000,origin=s0,scale=1e6,label='Waktu sejak core menerima SIGN (ms)')
axes[1].set_title('B. Setelah scalar selesai — konversi affine, inversi nonce, dan signature',loc='left',pad=13)
fig.suptitle('PURI-Sign | Detail tahap signing',x=.20,y=.985,ha='left',fontsize=18,fontweight='bold')
fig.text(.20,.945,'Dua jendela zoom terpisah; rentang scalar yang panjang berada di antara panel A dan B.',fontsize=10,color='#55616d')
fig.text(.20,.04,'Sumbu waktu linear di masing-masing panel. Nilai sinyal berasal dari transisi kontrol RTL; bukan timing fisik hasil routing.\nPulsa satu siklus dapat tampak sebagai garis tipis pada skala µs/ms.',fontsize=10,color='#55616d')
save(fig,'02_signing_detail')

fig,axes=plt.subplots(1,3,figsize=(19,8))
fig.subplots_adjust(left=.115,right=.985,top=.82,bottom=.19,wspace=.60)
names=['clk_stimulus','cmd_sign','cmd_zeroize','core_busy','sign_owner','sign_start','scalar_busy',
       'sign_done','done_latch','key_valid','key_locked','sign_valid','zeroize']
for ax,origin,lo,hi,title in [(axes[0],s0,s0-80,s0+240,'A. Penerimaan SIGN'),
                              (axes[1],s1,s1-240,s1+160,'B. Hasil signature valid'),
                              (axes[2],z0,z0-160,z0+240,'C. ZEROIZE saat scalar aktif')]:
    waves(ax,names,lo,hi,origin=origin,scale=40,label='Siklus relatif (1 siklus = 40 ns)')
    ax.xaxis.set_major_locator(MaxNLocator(integer=True,nbins=6))
    ax.axvline(0,color='#111827',lw=.8,ls='--',alpha=.6)
    ax.set_title(title,loc='left',pad=14)
fig.suptitle('PURI-Sign | Handshake dan ZEROIZE per siklus',x=.115,y=.98,ha='left',fontsize=18,fontweight='bold')
fig.text(.115,.925,'Titik nol: A = core menerima SIGN; B = core menyimpan signature; C = core menerima ZEROIZE.',fontsize=11,color='#55616d')
fig.text(.115,.06,'Clock direkonstruksi persis dari stimulus testbench (#20); sinyal lainnya berasal dari transisi RTL.\nsign_valid menyimpan status signature sebelumnya saat signing berikutnya berjalan, lalu dibersihkan oleh ZEROIZE.\nReset mesin bersama terlihat pada siklus C=0; key_valid/key_locked dibersihkan pada siklus berikutnya.',fontsize=10,color='#55616d')
save(fig,'03_handshake_zeroize')

# Export settled event values as a compact standard VCD, intentionally without clock.
with (out/'control_events.vcd').open('w') as f:
    f.write('$comment Event-driven RTL control transitions. Delta cycles collapsed; no full clock or secret datapath. $end\n$timescale 1ns $end\n$scope module puri_sign_control $end\n')
    for i,sig in enumerate(schema['signals']): f.write(f"$var wire {sig['width']} s{i} {sig['name']} $end\n")
    f.write('$upscope $end\n$enddefinitions $end\n')
    previous={}
    for row in rows:
        f.write(f"#{row['time_ns']}\n")
        for i,sig in enumerate(schema['signals']):
            n=sig['name'];v=row[n]
            if previous.get(n)!=v:
                f.write(f'b{v:0{sig["width"]}b} s{i}\n');previous[n]=v
    f.write(f'#{end}\n')

phase_names={0:'Penerimaan / publikasi hasil',2:'RFC6979',4:'Scalar kG',6:'Inversi Z modulo p',
             8:'Kuadrat Z^-1 modulo p',10:'Konversi x dan pembentukan r',12:'Inversi k modulo n',
             14:'Perkalian r*d modulo n',16:'Penjumlahan z + r*d',18:'Perkalian untuk s'}
phases=[]
for a,b,v in segments('sign_state'):
    left,right=max(a,s0),min(b,s1)
    if right>left: phases.append({'state':v,'phase':phase_names[v], 'start_ns':left-s0,
                                  'duration_cycles':(right-left)//40,'duration_us':(right-left)/1000})
assert sum(p['duration_cycles'] for p in phases)==7437840
metadata={'source':'Verilator RTL event trace; not hardware measurement or post-route timing',
          'clock_period_ns':40,'provision_cycles':(p1-p0)//40,'sign_cycles':(s1-s0)//40,
          'provision_ms':(p1-p0)/1e6,'sign_ms':(s1-s0)/1e6,
          'zeroize_accept_ns':z0,'stages_include_controller_handshake':True,'signing_stages':phases,
          'artifacts':ART+['control_events.vcd','control_events.csv'],
          'sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in list((ROOT/'rtl').glob('*/*.v'))+[ROOT/'tb/tb_puri_timing.v',out/'control_events.csv']}}
(out/'timing_summary.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps({k:metadata[k] for k in ['provision_cycles','sign_cycles','provision_ms','sign_ms','signing_stages']},indent=2))
