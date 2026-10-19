"""Compare matched CPU-observed Stage 1/Stage 2 timing reports."""
import argparse,csv,json
from pathlib import Path


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline_run',type=Path)
    p.add_argument('--stage2',type=Path,default=Path(__file__).resolve().parents[1]/'reference_stage2/summary.json')
    a=p.parse_args();stage1=json.loads((a.baseline_run/'summary.json').read_text());stage2=json.loads(a.stage2.read_text())
    if not stage1['overall_pass'] or not stage2['overall_pass']:raise SystemExit('Both runs must pass before comparison.')
    if stage1.get('compiler_optimization_enabled') != 1 or stage2.get('compiler_optimization_enabled') != 1:raise SystemExit('Both builds must have optimization enabled. Confirm exact -O2 in build logs separately.')
    if stage1['counter_hz'] != stage2['counter_hz']:raise SystemExit('Counter frequencies differ; investigate configuration before comparison.')
    rows=[]
    for b,g in zip(stage1['statistics'],stage2['statistics']):
        if b['bytes'] != g['bytes'] or b['samples'] != 31 or g['samples'] != 31:raise SystemExit('Sample sets differ.')
        row={'bytes':b['bytes']}
        for phase in ['capture','auth','release','cleanup','validation','total']:
            x,y=b[phase+'_us']['median'],g[phase+'_us']['median']
            row.update({phase+'_stage1_us':x,phase+'_stage2_us':y,phase+'_stage2_minus_stage1_us':y-x,phase+'_change_pct':100*(y/x-1)})
        row.update(stage1_pipeline_MBps=b['capture_auth_release_median_MBps'],stage2_pipeline_MBps=g['capture_auth_release_median_MBps'],stage1_total_MBps=b['total_including_cleanup_and_validation_median_MBps'],stage2_total_MBps=g['total_including_cleanup_and_validation_median_MBps'])
        rows.append(row)
    if len(rows)!=7:raise SystemExit('Expected seven sizes.')
    out=a.baseline_run/'stage1_vs_stage2.csv'
    with out.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    print('Wrote:',out.resolve())
    print('Positive deltas mean Stage 2 took longer. Differences include firmware release reconfiguration and physical implementation changes; they are not isolated guard RTL latency.')


if __name__=='__main__':main()
