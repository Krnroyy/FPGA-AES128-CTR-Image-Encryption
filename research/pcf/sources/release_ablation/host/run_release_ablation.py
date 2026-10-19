"""Record a paired release-policy experiment; transmit no UART data."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import re
import time


def assess(lines, expected):
    profile='STAGE1_TRUSTED_FIRMWARE' if expected=='stage1' else 'STAGE2_GUARD'
    starts=[i for i,l in enumerate(lines) if l=='PCF_RELEASE_ABLATION_START']
    active=lines[starts[-1]:] if starts else []
    wanted=['ABLATION_RESULT AUTHENTICATED_CONTROL EXACT_21_BYTES']
    for name,verdict in [('RAW_DECRYPT_VALID_TAG','TAG_MATCH'),('RAW_DECRYPT_BAD_TAG','AUTH_FAIL')]:
        wanted.append(f'ABLATION_RESULT {name} '+(f'EXPOSED_EXACT_21_BYTES {verdict}' if expected=='stage1' else 'BLOCKED_PROBE_UNCHANGED'))
    found=[l for l in active if l.startswith('ABLATION_RESULT ')]
    errors=[]
    if len(starts)!=1:errors.append('Expected one startup')
    if 'ABLATION_PROFILE '+profile not in active:errors.append('Wrong hardware profile: program the intended bitstream')
    if found!=wanted:errors.append('Expected outcomes missing, different, or duplicated')
    if 'ABLATION_OVERALL PASS' not in active:errors.append('Application did not complete successfully')
    if any(l.startswith(('ABLATION_FAILURE_STATE','ABLATION_OVERALL FAIL')) for l in active):errors.append('Application reported a failure')
    states=[l for l in active if l.startswith('ABLATION_STATE ')]
    if len(states)!=2:errors.append('Expected two raw-attempt status snapshots')
    for l in states:
        match=re.fullmatch(r'ABLATION_STATE (RAW_DECRYPT_VALID_TAG|RAW_DECRYPT_BAD_TAG) GUARD ([0-9a-fA-F]{8}) BUFFER ([0-9a-fA-F]{8}) GCM ([0-9a-fA-F]{8}) S2MM ([0-9a-fA-F]{8})',l)
        if not match:errors.append('Malformed state snapshot');continue
        guard,buffer,gcm,dma=(int(match[i],16) for i in [2,3,4,5])
        if expected=='stage2':
            if guard & 0xFFFF010C != 0x52470100 or buffer & 0x41 != 0x41 or dma & 0x1770:errors.append('Blocked-case state mismatch')
        elif guard!=0 or dma & 0x1770 != 0x1000 or gcm & 0x22 != 0x22 or gcm & 0xC0 != (0x80 if match[1]=='RAW_DECRYPT_BAD_TAG' else 0x40):errors.append('Exposed-case state mismatch')
    return {'stage':'paired_release_policy_ablation','expected_profile':profile,'overall_pass':not errors,
            'results':found,'state_snapshots':states,'errors':errors,
            'scope':'Trusted provisioned context; identical prohibited raw-decrypt command stream; firmware-observed DMA status and 64-byte destination probe.',
            'interpretation':'Stage 1 exposure is an expected consequence of bypassing trusted firmware sequencing, not a claimed AES-GCM flaw. Stage 2 should block that command sequence.'}


def synthetic(expected):
    lines=['PCF_RELEASE_ABLATION_START','ABLATION_PROFILE '+('STAGE1_TRUSTED_FIRMWARE' if expected=='stage1' else 'STAGE2_GUARD'),'ABLATION_RESULT AUTHENTICATED_CONTROL EXACT_21_BYTES']
    for name,status,tag in [('RAW_DECRYPT_VALID_TAG',0x62,'TAG_MATCH'),('RAW_DECRYPT_BAD_TAG',0xA2,'AUTH_FAIL')]:
        if expected=='stage1':
            lines.append(f'ABLATION_STATE {name} GUARD 00000000 BUFFER 00000414 GCM {status:08x} S2MM 00001002')
            lines.append(f'ABLATION_RESULT {name} EXPOSED_EXACT_21_BYTES {tag}')
        else:
            lines.append(f'ABLATION_STATE {name} GUARD 52470100 BUFFER 00000841 GCM 00000000 S2MM 00000000')
            lines.append(f'ABLATION_RESULT {name} BLOCKED_PROBE_UNCHANGED')
    return lines+['ABLATION_OVERALL PASS']


def save(folder,lines,expected,error=None):
    r=assess(lines,expected)
    if error:r['errors'].append(error);r['overall_pass']=False
    (folder/'summary.json').write_text(json.dumps(r,indent=2)+'\n')
    print('ABLATION MONITOR OVERALL:','PASS' if r['overall_pass'] else 'FAIL')
    for e in r['errors']:print(e)
    print('Evidence:',folder.resolve())
    return 0 if r['overall_pass'] else 1


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port');p.add_argument('--expect',choices=['stage1','stage2']);p.add_argument('--timeout',type=float,default=120)
    p.add_argument('--self-test',action='store_true');a=p.parse_args()
    if a.self_test:
        for e in ['stage1','stage2']:
            lines=synthetic(e)
            assert assess(lines,e)['overall_pass']
            assert not assess(lines[:-1],e)['overall_pass']
            assert not assess(lines+lines,e)['overall_pass']
            assert not assess(lines,'stage2' if e=='stage1' else 'stage1')['overall_pass']
            assert not assess(lines+[lines[2]],e)['overall_pass']
        print('OFFLINE MONITOR PASS: 10 checks; FPGA not tested.');return 0
    if not a.port or not a.expect:p.error('Use --port COM6 --expect stage1 (or stage2)')
    import serial
    folder=Path('release_ablation_'+a.expect+'_run_'+datetime.now().strftime('%Y%m%d_%H%M%S_%f'));folder.mkdir()
    lines=[];error=None
    try:
        with serial.Serial(a.port,115200,timeout=.2) as port:
            print('Port open. Now launch the ablation app on '+a.expect+' hardware.',flush=True)
            deadline=time.monotonic()+a.timeout;pending=bytearray();started=False
            with (folder/'uart_transcript.txt').open('w') as f:
                while time.monotonic()<deadline:
                    pending.extend(port.read(port.in_waiting or 1))
                    while b'\n' in pending:
                        raw,_,rest=pending.partition(b'\n');pending=bytearray(rest)
                        line=raw.decode('ascii',errors='replace').rstrip('\r');lines.append(line);f.write(line+'\n');f.flush();print(line,flush=True)
                        started|=line=='PCF_RELEASE_ABLATION_START'
                        if started and line.startswith('ABLATION_OVERALL '):return save(folder,lines,a.expect)
                if pending:f.write(pending.decode('ascii',errors='replace'))
            error='Timed out waiting for application completion'
    except (serial.SerialException,OSError,KeyboardInterrupt) as exc:error=str(exc) or 'Interrupted'
    return save(folder,lines,a.expect,error)


if __name__=='__main__':raise SystemExit(main())
