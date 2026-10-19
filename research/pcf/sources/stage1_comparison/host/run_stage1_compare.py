"""Record and assess the original Stage 1 matched benchmark. UART receive only."""
import argparse
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import statistics
import time

ROOT = Path(__file__).resolve().parent
MANIFEST = json.loads((ROOT / 'suite_manifest.json').read_text())
EXPECTED = []

FIELDS = ['size', 'sample', 'capture_ticks', 'auth_ticks', 'release_ticks',
          'cleanup_ticks', 'total_ticks', 'validation_ticks']


def percentile(values, fraction):
    values = sorted(values)
    pos = (len(values)-1)*fraction
    lower = int(pos)
    return values[lower] + (values[min(lower+1, len(values)-1)]-values[lower])*(pos-lower)


def assess(lines):
    errors, samples, passed = [], [], []
    starts = [i for i, line in enumerate(lines) if line == 'PCF_STAGE1_BENCHMARK_START']
    active = lines[starts[-1]:] if starts else []
    if len(starts) != 1:
        errors.append('Expected exactly one combined application startup')
    frequency = None
    optimization = None
    overhead = None
    def metadata_integer(line):
        try:
            return int(line.split()[-1])
        except ValueError:
            errors.append('Malformed metadata: '+line)
            return None
    for line in active:
        if line.startswith('PERF_COUNTER_HZ '):
            frequency = metadata_integer(line)
        elif line.startswith('PERF_COMPILER_OPTIMIZATION_ENABLED '):
            optimization = metadata_integer(line)
        elif line.startswith('PERF_COUNTER_READ_OVERHEAD_TICKS '):
            overhead = metadata_integer(line)
        elif line.startswith('SWEEP_TEST_PASS '):
            passed.append(line.split()[1])
            pos = re.fullmatch(r'SWEEP_TEST_PASS N_(\d+)_(VALID|VALID_AFTER_REJECTIONS) EXACT_BYTES (\d+) GUARD ([0-9a-fA-F]{8})', line)
            neg = re.fullmatch(r'SWEEP_TEST_PASS (\S+) GUARD ([0-9a-fA-F]{8}) BUFFER ([0-9a-fA-F]{8}) S2MM ([0-9a-fA-F]{8}) PROBE_UNCHANGED', line)
            if pos:
                if pos[1] != pos[3] or int(pos[4],16) != 0x52470011:
                    errors.append('Incorrect recovery marker: '+line)
            elif neg:
                guard,buffer,dma = (int(neg[i],16) for i in [2,3,4])
                if guard & 0xFFFF010C != 0x52470100 or buffer & 0x41 != 0x41 or dma & 0x1770:
                    errors.append('Incorrect rejection marker: '+line)
            else:
                errors.append('Malformed sweep result: '+line)
        elif line.startswith('PERF_SAMPLE '):
            try:
                values = list(map(int,line.split()[1:]))
                if len(values) != 8 or any(v < 0 or v > 0xFFFFFFFF for v in values):
                    raise ValueError()
                sample = dict(zip(FIELDS,values))
                if sample['total_ticks'] != sum(sample[k] for k in ['capture_ticks','auth_ticks','release_ticks','cleanup_ticks','validation_ticks']):
                    raise ValueError()
                if any(sample[k] <= 0 for k in ['capture_ticks','auth_ticks','release_ticks','cleanup_ticks','total_ticks']):
                    raise ValueError()
                samples.append(sample)
            except ValueError:
                errors.append('Malformed timing sample: '+line)
        if line.startswith(('SWEEP_TEST_FAIL','BASELINE_FAILURE_STATE','BASELINE_OVERALL FAIL')):
            errors.append(line)
    if passed != EXPECTED:
        errors.append('Sweep results missing, duplicated, or out of order')
    if not any(l == 'BASELINE_RESERVED_68 00000000' for l in active):
        errors.append('Expected Stage 1 reserved register missing (this is not unique hardware identification)')
    if frequency is None or not 1 <= frequency <= 0xFFFFFFFF:
        errors.append('Valid counter frequency missing')
        frequency = None
    if optimization not in [0,1] or overhead is None:
        errors.append('Compiler/timer metadata missing')
    expected_samples = [(n,i) for n in MANIFEST['benchmark_lengths'] for i in range(31)]
    if [(s['size'],s['sample']) for s in samples] != expected_samples:
        errors.append('Benchmark samples missing, duplicated, or out of order')
    for marker in ['PERF_SAMPLES_PASSED 217 EXPECTED 217', 'BASELINE_OVERALL PASS']:
        if marker not in active:
            errors.append('Missing '+marker)
    report = {'stage':'stage1_trusted_firmware_matched_benchmark', 'overall_pass':not errors,
              'suite_seed':MANIFEST['seed'], 'sweep_passed':passed, 'sweep_expected_count':0,
              'benchmark_sample_count':len(samples), 'counter_hz':frequency,
              'counter_read_overhead_ticks':overhead, 'compiler_optimization_enabled':optimization,
              'compiler':[l[len('PERF_COMPILER '):] for l in active if l.startswith('PERF_COMPILER ')],
              'errors':errors, 'scope':'Firmware status and payload-plus-64-byte destination probes; no independent DDR bus monitor.',
              'timing_scope':'CPU-observed DMA/crypto/software orchestration; no UART inside intervals. Initialization outside total; validation gaps included in total. Not pure hardware throughput.',
              'statistics':[]}
    if frequency:
        for n in MANIFEST['benchmark_lengths']:
            group = [s for s in samples if s['size'] == n]
            if len(group) != 31:
                continue
            row = {'bytes':n,'samples':len(group)}
            for phase in ['capture','auth','release','cleanup','total','validation']:
                us = [s[phase+'_ticks']*1e6/frequency for s in group]
                row[phase+'_us'] = {'min':min(us),'p5':percentile(us,.05),'median':statistics.median(us),'p95':percentile(us,.95),'max':max(us)}
            processing_us = [(s['capture_ticks']+s['auth_ticks']+s['release_ticks'])*1e6/frequency for s in group]
            row['capture_auth_release_median_us'] = statistics.median(processing_us)
            row['capture_auth_release_median_MBps'] = n/statistics.median(processing_us)
            row['total_including_cleanup_and_validation_median_MBps'] = n/row['total_us']['median']
            report['statistics'].append(row)
    return report,samples


def save(folder, lines, error=None):
    report,samples = assess(lines)
    if error:
        report['errors'].append(error)
        report['overall_pass'] = False
    (folder/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    with (folder/'samples.csv').open('w',newline='') as out:
        writer=csv.DictWriter(out,fieldnames=FIELDS);writer.writeheader();writer.writerows(samples)
    with (folder/'statistics.csv').open('w',newline='') as out:
        names=['bytes','samples']+[p+'_'+q+'_us' for p in ['capture','auth','release','cleanup','total','validation'] for q in ['min','p5','median','p95','max']]+['capture_auth_release_median_us','capture_auth_release_median_MBps','total_including_cleanup_and_validation_median_MBps']
        writer=csv.DictWriter(out,fieldnames=names);writer.writeheader()
        for row in report['statistics']:
            flat={k:v for k,v in row.items() if not isinstance(v,dict)}
            for p in ['capture','auth','release','cleanup','total','validation']:
                flat.update({p+'_'+q+'_us':v for q,v in row[p+'_us'].items()})
            writer.writerow(flat)
    print('BASELINE MONITOR OVERALL:', 'PASS' if report['overall_pass'] else 'FAIL')
    for error in report['errors'][:5]: print(error)
    print('Evidence:', folder.resolve())
    return 0 if report['overall_pass'] else 1


def synthetic_lines():
    lines=['PCF_STAGE1_BENCHMARK_START','BASELINE_RESERVED_68 00000000',
           'PERF_COUNTER_HZ 1000000','PERF_COUNTER_READ_OVERHEAD_TICKS 1',
           'PERF_COMPILER_OPTIMIZATION_ENABLED 1','PERF_COMPILER mock']
    for n in MANIFEST['benchmark_lengths']:
        for i in range(31):lines.append(f'PERF_SAMPLE {n} {i} 10 20 20 10 65 5')
    return lines+['PERF_SAMPLES_PASSED 217 EXPECTED 217','BASELINE_OVERALL PASS']


def self_test():
    lines=synthetic_lines();report,samples=assess(lines)
    assert report['overall_pass'] and len(samples)==217 and len(report['statistics'])==7
    assert not assess(lines[:-1])[0]['overall_pass']
    assert not assess(lines+lines)[0]['overall_pass']
    assert not assess([x for x in lines if not x.startswith('PERF_SAMPLE 16 0 ')])[0]['overall_pass']
    assert not assess([x.replace('10 20 20 10 65 5','10 20 20 10 64 5') for x in lines])[0]['overall_pass']
    assert not assess([x.replace('BASELINE_RESERVED_68 00000000','BASELINE_RESERVED_68 52470000') for x in lines])[0]['overall_pass']
    assert not assess([x.replace('PERF_COUNTER_HZ 1000000','PERF_COUNTER_HZ invalid') for x in lines])[0]['overall_pass']
    print('OFFLINE BASELINE MONITOR PASS: 7 checks; FPGA not tested.')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port');p.add_argument('--baud',type=int,default=115200)
    p.add_argument('--timeout',type=float,default=300);p.add_argument('--output',type=Path)
    p.add_argument('--self-test',action='store_true');p.add_argument('--analyze',type=Path)
    args=p.parse_args()
    if args.self_test:self_test();return 0
    if not args.port and not args.analyze:p.error('Use --port COM6 or --analyze uart_transcript.txt')
    folder=args.output or Path('stage1_compare_run_'+datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    folder.mkdir(parents=True,exist_ok=False)
    if args.analyze:
        lines=args.analyze.read_text().splitlines()
        (folder/'uart_transcript.txt').write_text('\n'.join(lines)+'\n')
        return save(folder,lines)
    import serial
    lines,error=[],None
    try:
        with serial.Serial(args.port,args.baud,timeout=.2) as port:
            print('Port open. Now launch stage1_compare_app in Vitis.',flush=True)
            deadline=time.monotonic()+args.timeout;pending=bytearray();started=False
            with (folder/'uart_transcript.txt').open('w') as transcript:
                while time.monotonic()<deadline:
                    pending.extend(port.read(port.in_waiting or 1))
                    while b'\n' in pending:
                        raw,_,rest=pending.partition(b'\n');pending=bytearray(rest)
                        line=raw.decode('ascii',errors='replace').rstrip('\r')
                        lines.append(line);transcript.write(line+'\n');transcript.flush()
                        if line.startswith('SWEEP_TEST_PASS '):
                            count=sum(x.startswith('SWEEP_TEST_PASS ') for x in lines)
                            if count%50==0:print(f'Sweep progress: {count}/640',flush=True)
                        elif not line.startswith(('SWEEP_TEST_BEGIN','PERF_SAMPLE')):
                            print(line,flush=True)
                        started |= line=='PCF_STAGE1_BENCHMARK_START'
                        if started and line.startswith('BASELINE_OVERALL '):return save(folder,lines)
                if pending:transcript.write(pending.decode('ascii',errors='replace'))
            error='Timed out waiting for combined completion'
    except (serial.SerialException,OSError,KeyboardInterrupt) as exc:
        error=str(exc) or 'Interrupted'
    return save(folder,lines,error)


if __name__=='__main__':raise SystemExit(main())
