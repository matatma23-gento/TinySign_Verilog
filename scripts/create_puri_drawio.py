#!/usr/bin/env python3
"""Create editable draw.io workflow pages and matching offline previews."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Polygon, Ellipse

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/diagrams/puri_sign'
OUT.mkdir(parents=True, exist_ok=True)
COLORS = {
    'blue': ('#EAF2FC', '#3973A8'), 'green': ('#E8F5EF', '#25816C'),
    'purple': ('#F0EBFA', '#8260A7'), 'amber': ('#FFF4DC', '#B68125'),
    'red': ('#FCEDED', '#B65050'), 'gray': ('#F2F5F8', '#7C8C9B'),
    'plain': ('#FFFFFF', '#FFFFFF')}
pages = []

class Page:
    def __init__(self, name, title, subtitle, height=1340):
        self.name, self.width, self.height = name, 1200, height
        self.nodes, self.edges = [], []
        self.text('title', title, 45, 25, 1110, 44, 28, True)
        self.text('subtitle', subtitle, 45, 77, 1110, 48, 16)
        self.text('footer', 'PURI-Sign | Berdasarkan RTL shared-engine, 8 Oktober 2026 | Diagram alur, bukan timing fisik',
                  45, height-45, 1110, 28, 13)
        pages.append(self)

    def node(self, id, text, x, y, w=440, h=78, color='blue', shape='box', size=16, bold=False):
        n=dict(id=id, text=text, x=x, y=y, w=w, h=h, color=color, shape=shape, size=size, bold=bold)
        self.nodes.append(n)
        return id

    def text(self, id, text, x, y, w, h, size=15, bold=False):
        return self.node(id,text,x,y,w,h,'plain','text',size,bold)

    def edge(self, a, b, start='bottom', end='top', via=(), color='#627588', dashed=False):
        self.edges.append(dict(a=a,b=b,start=start,end=end,via=list(via),color=color,dashed=dashed))

    def chain(self, *ids):
        for a,b in zip(ids,ids[1:]): self.edge(a,b)

p=Page('01 Alur utama', 'PURI-Sign | Alur kerja sistem',
       'Host menyiapkan input; FPGA menyimpan kunci dan menghitung signature ECDSA P-256.', 1450)
p.node('begin','Reset / awal penggunaan',100,145,440,58,'gray','ellipse')
p.node('load','HOST → FPGA\nTulis private key d: 8 word × 32 bit',100,243)
p.node('prov','CMD_PROVISION = 1\nValidasi key → hitung public key Q = dG',100,361,440,86)
p.node('lock','CMD_LOCK = 2\nkey_valid = 1 → key_locked = 1',100,487,440,78,'green')
p.node('doc','HOST\nHash dokumen → digest SHA-256 256 bit',100,605,440,78,'gray')
p.node('digest','HOST → FPGA\nTulis digest: 8 word × 32 bit',100,723)
p.node('sign','CMD_SIGN = 4\nCore memeriksa key_valid dan key_locked',100,841,440,86,'green')
p.node('compute','FPGA: jalankan signing\nRFC6979 → kG → r dan s',100,967,440,78,'green')
p.node('read','HOST: tunggu transaksi selesai\nPeriksa busy / done / error; baca r dan s',100,1085,440,86,'gray')
p.node('result','Signature tersedia untuk dokumen\nVerifikasi dilakukan di luar core ini',100,1211,440,78,'gray','ellipse')
p.chain('begin','load','prov','lock','doc','digest','sign','compute','read','result')
p.node('q','Public key Q = (Qx, Qy) dapat dibaca\nCMD_GET_PUB = 3 memeriksa key_valid\nDetail provisioning: halaman 02',680,355,450,110,'blue')
p.edge('prov','q','right','left')
p.node('hostnote','BATAS HOST / CORE\nCore menerima digest, bukan file dokumen.\nSHA-256 di jalur nonce dipakai HMAC.\nPrivate key berasal dari provisioning host;\ntidak ada generator key acak pada alur ini.',680,600,450,155,'gray')
p.node('timing','LATENSI SIMULASI @ 25 MHz\nProvisioning: 292,14824 ms\nSigning: 297,51360 ms\nTidak termasuk transfer input/output host.',680,835,450,125,'amber')
p.node('repeat','TRANSAKSI BERIKUTNYA\nKunci tetap tersimpan dan terkunci.\nHost menulis digest baru, lalu CMD_SIGN.\nUntuk mengganti kunci: ZEROIZE dahulu.',680,1020,450,125,'green')
p.node('z','ZEROIZE dapat menyela operasi aktif.\nPenanganan pembatalan / error: halaman 05.\nSetiap operasi wajib memeriksa status error.',680,1210,450,95,'red')

p=Page('02 Provisioning', 'Provisioning | Validasi, public key, dan lock',
       'Owner engine = PROVISION. Private key tidak tersedia pada jalur pembacaan register.',1460)
p.node('input','Tulis 8 word private key ke staging\nKemudian CMD_PROVISION',100,150)
p.node('valid','Key belum valid, 8 word lengkap,\ndan 1 ≤ d < n?',100,275,440,120,'amber','diamond',15)
p.node('scalar','SHARED SCALAR\nHitung Q = dG → koordinat Jacobian (X,Y,Z)',100,450,440,86,'blue')
p.node('inv','SHARED INVERSE\nu = Z⁻¹ mod p',100,580,440,78,'purple')
p.node('mul','SHARED MULTIPLY, dipakai berurutan\nu² → u³ → Qx = X·u² → Qy = Y·u³\nSemua operasi modulo p',100,700,440,105,'purple')
p.node('commit','Simpan d pada key_reg; simpan Qx dan Qy\nkey_valid = 1; bersihkan staging / sementara\nCore: done = 1, kembali IDLE',100,850,440,105,'green')
p.node('lock','HOST: CMD_LOCK\nKey valid → key_locked = 1',100,1000,440,78,'green')
p.node('ready','Kunci siap dipakai signing\nReadback private key tetap 0',100,1125,440,78,'green','ellipse')
p.chain('input','valid','scalar','inv','mul','commit','lock','ready')
p.text('yes','Ya',290,405,60,28)
p.node('invalid','Tolak provisioning\nkey_error → core error_code = 0x02\nTidak meneruskan perhitungan public key',710,285,420,100,'red')
p.edge('valid','invalid','right','left')
p.text('no','Tidak',580,305,100,28)
p.node('error','Jika salah satu engine mengirim error:\nhentikan urutan controller → IDLE\nCore melaporkan error_code = 0x02\nHost memeriksa error sebelum lanjut.',710,595,420,125,'red')
p.node('policy','ATURAN KEY\nPenulisan key ditolak jika key_valid\natau key_locked sudah aktif.\nLOCK memerlukan key yang valid.\nPenggantian key dimulai dengan ZEROIZE.',710,850,420,150,'gray')
p.node('symbols','NOTASI\np: modulus field P-256\nn: orde subgroup P-256\nG: base point; d: private key',710,1130,420,115,'gray')
p.node('latency','7.303.706 siklus core = 292,14824 ms pada 25 MHz\nAngka berasal dari trace simulasi; tidak mencakup penulisan 8 word key atau CMD_LOCK.',100,1280,1030,82,'amber')

p=Page('03 Signing ECDSA', 'Signing | Dari digest menjadi signature (r, s)',
       'Owner engine = SIGN. p adalah modulus field; n adalah orde subgroup; seluruh operand utama 256 bit.',1770)
p.node('start','HOST: tulis digest, lalu CMD_SIGN',85,145,500,65,'gray')
p.node('check','key_valid = 1 dan key_locked = 1?',85,255,500,110,'amber','diamond',15)
p.node('latch','Signer menyalin private key d\nValidasi 1 ≤ d < n; z = digest mod n',85,415,500,80,'green')
p.node('nonce','RFC6979 → HMAC-SHA-256\nBentuk nonce deterministik k dari d dan z',85,535,500,85,'purple')
p.node('scalar','SHARED SCALAR\nR = kG → (X, Y, Z) Jacobian',85,660,500,80,'blue')
p.node('affine','SHARED INVERSE + MULTIPLY\nu = Z⁻¹ mod p; x = X·u² mod p\nr = x mod n',85,780,500,100,'purple')
p.node('rcheck','r ≠ 0?',85,925,500,105,'amber','diamond')
p.node('kinv','SHARED INVERSE\nv = k⁻¹ mod n',85,1075,500,75,'purple')
p.node('math','SHARED MULTIPLY + mod_add lokal\nt = (z + r·d) mod n\ns = v·t mod n',85,1190,500,95,'purple')
p.node('scheck','s ≠ 0?',85,1325,500,105,'amber','diamond')
p.node('publish','Signer: keluarkan r,s; hapus d_reg dan k_reg\nCore: simpan r,s; sign_valid = 1; done = 1\nKembali IDLE; key_manager tetap menyimpan d',85,1475,500,105,'green')
p.chain('start','check','latch','nonce','scalar','affine','rcheck','kinv','math','scheck','publish')
for id,y in [('y1',378),('y2',1035),('y3',1435)]: p.text(id,'Ya',310,y,50,28)
p.node('reject','Tolak CMD_SIGN\nCore: error_code = 0x01\nSigner tidak dijalankan',760,255,355,100,'red')
p.edge('check','reject','right','left')
p.text('no1','Tidak',630,275,75,28)
p.node('nonce_note','Nonce tidak dibaca oleh host.\nInput key + digest yang sama\nmenghasilkan nonce deterministik.',755,535,365,95,'gray')
p.node('failed','GAGAL TRANSAKSI SIGNER\nr/s internal, d_reg, k_reg dibersihkan\nSigner memberi error → IDLE\nCore: error_code = 0x02\nTidak ada retry otomatis untuk r/s = 0',745,1120,390,140,'red')
p.edge('rcheck','failed','right','top',[(940,977)])
p.edge('scheck','failed','right','bottom',[(940,1377)])
p.text('no2','Tidak',620,945,75,28)
p.text('no3','Tidak',620,1350,75,28)
p.node('engine_err','Error dari nonce / scalar / inverse /\nmultiply / add juga menuju\nGAGAL TRANSAKSI SIGNER.',745,785,390,100,'red')
p.node('status','STATUS HASIL\nsign_valid dan r/s core dapat masih\nmemuat hasil transaksi sebelumnya.\nHost harus memeriksa busy, done, error\nuntuk menentukan hasil transaksi baru.',735,1460,410,130,'amber')
p.node('latency','7.437.840 siklus core = 297,51360 ms @ 25 MHz\nTahap scalar sekitar 286,761 ms; angka simulasi mencakup handshake controller.',85,1630,1050,80,'amber')

p=Page('04 Engine bersama', 'Arsitektur | Dua controller, satu kelompok engine',
       'Pemilihan owner mengikuti FSM perintah core; provisioning dan signing tidak berjalan bersamaan.',1440)
p.node('host','HOST / antarmuka register Avalon-MM\nCMD, STATUS, key input, digest, public key, signature',230,150,740,85,'gray')
p.node('fsm','tinysign_core: FSM perintah\nIDLE → PROVISION_WAIT / LOCK_WAIT / SIGN_WAIT / ZEROIZE_WAIT',170,300,860,95,'blue')
p.edge('host','fsm')
p.node('km','key_manager\nStaging key → validasi → Q = dG\nPenyimpanan private key + public key\nSHARED_ENGINES = 1',75,470,450,130,'blue')
p.node('sg','ecdsa_signer\nRFC6979 / HMAC-SHA-256 + mod_add\nUrutan ECDSA; hasil r,s\nSHARED_ENGINES = 1',675,470,450,130,'green')
p.edge('fsm','km','bottom','top',[(600,430),(300,430)])
p.edge('fsm','sg','bottom','top',[(600,430),(900,430)])
p.edge('km','sg','right','left')
p.text('keylabel','d internal',529,493,141,30,14)
p.node('mux','Pemilih operand / start dan pemilah done / error\nprovision_owner atau sign_owner berasal dari FSM\nRespons selesai/error hanya diteruskan kepada owner aktif',195,730,810,115,'purple')
p.edge('km','mux','bottom','left',[(300,655),(145,655),(145,787)])
p.edge('sg','mux','bottom','right',[(900,655),(1055,655),(1055,787)])
p.node('scalar','1 × scalar_mult\ndG atau kG\npoint_ops internal',65,970,330,125,'blue')
p.node('inv','1 × mod_inv\nZ⁻¹ mod p atau k⁻¹ mod n\nAritmetika internal sendiri',435,970,330,125,'purple')
p.node('mul','1 × mod_mul di level core\nKonversi affine dan\nperkalian ECDSA',805,970,330,125,'purple')
for id,cx in [('scalar',230),('inv',600),('mul',970)]:
    p.edge('mux',id,'bottom','top',[(600,910),(cx,910)])
p.node('counts','JUMLAH FISIK HIERARKIS\nScalar engine: 2 → 1  |  Inverse engine: 2 → 1\nTotal mod_mul seluruh hierarki: 8 → 4 (bukan hanya satu multiplier di seluruh chip).\nRFC6979 / HMAC sejak awal berada pada signer; tidak dihitung sebagai duplikasi yang dihapus.',65,1170,1070,130,'amber')
p.text('note','Panah menunjukkan jalur request / pemakaian. Hasil engine kembali melalui pemilah respons pada blok tengah.',65,1330,1070,35,14)

p=Page('05 Zeroize dan error', 'Kontrol | ZEROIZE, status, dan penolakan akses',
       'ZEROIZE adalah pengecualian saat busy; perintah harus ditulis dengan byte_enable = 0xF.',1490)
p.node('command','HOST: CMD_ZEROIZE = 5\nDapat dikirim saat idle maupun operasi aktif',70,150,520,85,'red')
p.node('abort','Core memicu key_zeroize\nPindah ke ZEROIZE_WAIT → owner dilepas\nHapus digest dan r/s core; sign_valid = 0',70,290,520,100,'red')
p.node('eng','Reset shared scalar / inverse / multiply\nClear signer dan RFC6979\nBatalkan pekerjaan yang sedang berlangsung',70,445,520,100,'red')
p.node('key','key_manager membersihkan staging, key,\npublic key dan state sementara\nkey_valid = 0; key_locked = 0; key_done = 1',70,600,520,100,'red')
p.node('idle','Core menerima key_done\ndone_latch = 1; busy = 0; zeroized = 1\nKembali IDLE',70,755,520,100,'green')
p.node('again','Host dapat melakukan provisioning baru',70,910,520,65,'green','ellipse')
p.chain('command','abort','eng','key','idle','again')
p.node('writes','BUS WRITE SAAT BUSY\nSelain CMD_ZEROIZE → error_code 0x03.\nOperasi aktif tetap berjalan;\npenolakan write tidak membatalkannya.',720,165,410,120,'amber')
p.node('byte','BYTE ENABLE / ALAMAT\nWrite harus satu word penuh (0xF).\nByte enable salah / alamat tidak didukung\n→ error_code 0x04.',720,335,410,120,'amber')
p.node('errors','ERROR PERINTAH / OPERASI\n0x01: command / prasyarat key tidak valid\n0x02: key_manager atau signer gagal\nStatus error harus diperiksa host.',720,505,410,120,'amber')
p.node('clear','CMD_CLEAR_STATUS = 6 (saat idle)\nHapus done/error/error_code, sign_valid,\ndan zeroized. Tidak menghapus key\natau isi register signature r/s.',720,675,410,120,'gray')
p.node('status','REGISTER STATUS\nready, busy, done, error, key_valid,\nkey_locked, sign_valid, zeroized\nReadback key selalu bernilai 0.',720,845,410,120,'gray')
p.node('timing','URUTAN PADA TRACE RTL @ 25 MHz\nT0: perintah diterima, key_zeroize aktif, shared engine berhenti dan sign_valid core turun.\nT0 + 1 siklus: key_valid dan key_locked turun.\nT0 + 2 siklus: core menyelesaikan ZEROIZE dan kembali idle.',70,1060,1060,135,'blue')
p.node('scope','BATAS DIAGRAM\nIni alur perilaku RTL yang tersedia, bukan klaim sertifikasi secure element atau ketahanan serangan fisik.\nReset/clear logika tidak membuktikan waktu penghapusan fisik. Latensi di atas berasal dari simulasi.\nIntegrasi clock 25 MHz, pin board, dan host tetap mengikuti batas implementasi proyek.',70,1240,1060,135,'gray')

ANCHOR = {'top':(.5,0),'bottom':(.5,1),'left':(0,.5),'right':(1,.5)}
def point(n, side):
    a,b=ANCHOR[side]
    return (n['x']+a*n['w'],n['y']+b*n['h'])

mxfile=ET.Element('mxfile',host='app.diagrams.net',type='device',version='24.7.17')
for page_no,p in enumerate(pages,1):
    diagram=ET.SubElement(mxfile,'diagram',id=f'puri-{page_no}',name=p.name)
    model=ET.SubElement(diagram,'mxGraphModel',dx='1200',dy=str(p.height),grid='1',gridSize='10',guides='1',
                        tooltips='1',connect='1',arrows='1',fold='1',page='1',pageScale='1',
                        pageWidth=str(p.width),pageHeight=str(p.height),math='0',shadow='0')
    root=ET.SubElement(model,'root')
    ET.SubElement(root,'mxCell',id='0'); ET.SubElement(root,'mxCell',id='1',parent='0')
    nodes={n['id']:n for n in p.nodes}
    for n in p.nodes:
        fill,stroke=COLORS[n['color']]
        shape={'box':'rounded=1;arcSize=12;', 'ellipse':'ellipse;', 'diamond':'rhombus;',
               'text':'text;strokeColor=none;fillColor=none;'}[n['shape']]
        style=f'{shape}whiteSpace=wrap;html=0;fontFamily=DejaVu Sans;fontSize={n["size"]};fontColor=#243746;'
        if n['shape']!='text': style+=f'fillColor={fill};strokeColor={stroke};strokeWidth=1.5;'
        style+=f'align={"left" if n["shape"]=="text" else "center"};verticalAlign=middle;spacing=8;'
        if n['bold']: style+='fontStyle=1;'
        cell=ET.SubElement(root,'mxCell',id=n['id'],value=n['text'],style=style,vertex='1',parent='1')
        ET.SubElement(cell,'mxGeometry',x=str(n['x']),y=str(n['y']),width=str(n['w']),height=str(n['h']),attrib={'as':'geometry'})
    for i,e in enumerate(p.edges):
        sx,sy=ANCHOR[e['start']]; tx,ty=ANCHOR[e['end']]
        style=(f'edgeStyle=orthogonalEdgeStyle;rounded=0;html=0;endArrow=block;endFill=1;strokeWidth=1.7;'
               f'strokeColor={e["color"]};exitX={sx};exitY={sy};exitDx=0;exitDy=0;'
               f'entryX={tx};entryY={ty};entryDx=0;entryDy=0;')
        if e['dashed']: style+='dashed=1;'
        cell=ET.SubElement(root,'mxCell',id=f'edge-{i}',style=style,edge='1',parent='1',source=e['a'],target=e['b'])
        geom=ET.SubElement(cell,'mxGeometry',relative='1',attrib={'as':'geometry'})
        if e['via']:
            arr=ET.SubElement(geom,'Array',attrib={'as':'points'})
            for x,y in e['via']: ET.SubElement(arr,'mxPoint',x=str(x),y=str(y))

    # Offline preview from the same nodes and coordinates; draw.io is not required.
    fig,ax=plt.subplots(figsize=(p.width/100,p.height/100),dpi=130)
    fig.subplots_adjust(0,0,1,1)
    ax.set(xlim=(0,p.width),ylim=(p.height,0)); ax.axis('off')
    for e in p.edges:
        pts=[point(nodes[e['a']],e['start']),*e['via'],point(nodes[e['b']],e['end'])]
        ax.plot([v[0] for v in pts],[v[1] for v in pts],color=e['color'],lw=1.2,zorder=1)
        ax.annotate('',xy=pts[-1],xytext=pts[-2],arrowprops=dict(arrowstyle='-|>',color=e['color'],lw=1.2,mutation_scale=13),zorder=1)
    for n in p.nodes:
        x,y,w,h=(n[k] for k in ['x','y','w','h']); fill,stroke=COLORS[n['color']]
        kw=dict(facecolor=fill,edgecolor=stroke,lw=1.1,zorder=2)
        if n['shape']=='box': patch=FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0,rounding_size=9',**kw)
        elif n['shape']=='ellipse': patch=Ellipse((x+w/2,y+h/2),w,h,**kw)
        elif n['shape']=='diamond': patch=Polygon([(x+w/2,y),(x+w,y+h/2),(x+w/2,y+h),(x,y+h/2)],**kw)
        else: patch=None
        if patch: ax.add_patch(patch)
        ax.text(x+8 if n['shape']=='text' else x+w/2,y+h/2,n['text'],
                fontsize=n['size']*.72,fontfamily='DejaVu Sans',fontweight='bold' if n['bold'] else 'normal',
                ha='left' if n['shape']=='text' else 'center',va='center',color='#243746',linespacing=1.5,zorder=3)
    stem=f'{page_no:02d}_'+['alur_utama','provisioning','signing','engine_bersama','zeroize_error'][page_no-1]
    fig.savefig(OUT/f'{stem}.png',facecolor='white')
    plt.rcParams['svg.fonttype']='none'
    fig.savefig(OUT/f'{stem}.svg',facecolor='white')
    plt.close(fig)

ET.indent(mxfile)
target=OUT/'PURI_Sign_Alur_Sistem.drawio'
ET.ElementTree(mxfile).write(target,encoding='utf-8',xml_declaration=True)
# Structural integrity: every edge has valid, editable vertex endpoints.
parsed=ET.parse(target)
for d in parsed.findall('diagram'):
    cells=d.findall('./mxGraphModel/root/mxCell'); ids=[c.get('id') for c in cells]
    assert len(ids)==len(set(ids)),d.get('name')
    for c in cells:
        if c.get('edge')=='1': assert c.get('source') in ids and c.get('target') in ids
manifest={'pages':[p.name for p in pages], 'source_sha256':{
    str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest()
    for f in [ROOT/'rtl/security/tinysign_core.v',ROOT/'rtl/security/key_manager.v',ROOT/'rtl/ecdsa/ecdsa_signer.v']},
    'preview_method':'Offline render from the same graph geometry; not a draw.io application screenshot.'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Created {target} with {len(pages)} editable pages and PNG/SVG previews.')
