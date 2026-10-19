#!/usr/bin/env python3
"""Run all four candidate RTL benches; any missing PASS or failure is fatal."""
import argparse,hashlib,json,pathlib,subprocess,sys,time
p=argparse.ArgumentParser();p.add_argument('--iverilog',default='iverilog');p.add_argument('--vvp',default='vvp');p.add_argument('--ivl-base');a=p.parse_args()
r=pathlib.Path(__file__).resolve().parent
out=r/'validation';out.mkdir(exist_ok=True)
for name,want in json.loads((r/'SHA256SUMS.json').read_text()).items():
 if hashlib.sha256((r/name).read_bytes()).hexdigest()!=want: raise SystemExit('Changed input: '+name)
checks={
 'tb_ProtectedChunkBuffer_AXIS':'PASS: PROTECTED CHUNK BUFFER RTL MILESTONE',
 'tb_ReleaseInterlock':'PASS: RTL RELEASE INTERLOCK MILESTONE',
 'tb_ControllerRaces':'CANDIDATE_RACES_PASS scenarios=16 pending_completion_collisions=9',
 'tb_CommittedPacket':'COMMITTED_PACKET_PASS cases=45 strict_axis_violations=0'}
summary={'scope':'Directed simulation only; no formal proof, Vivado implementation, or board validation','tests':{}}
for top,marker in checks.items():
 exe=out/(top+'.vvp');cmd=[a.iverilog]
 if a.ivl_base:cmd+=['-B',a.ivl_base]
 cmd+=['-g2012','-s',top,'-o',str(exe),*map(str,sorted((r/'rtl').glob('*.v'))),str(r/'sim'/(top+'.v'))]
 c=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (out/(top+'_compile.log')).write_text(c.stdout)
 if c.returncode:raise SystemExit(c.stdout)
 t=time.monotonic();c=subprocess.run([a.vvp,'-i',str(exe)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (out/(top+'.log')).write_text(c.stdout)
 ok=c.returncode==0 and marker in c.stdout and not any(x in c.stdout for x in ['FATAL:','FAIL:','AXIS_PROTOCOL_VIOLATION '])
 summary['tests'][top]={'pass':ok,'returncode':c.returncode,'elapsed_seconds':round(time.monotonic()-t,3)}
 print(top+': '+('PASS' if ok else 'FAIL'),flush=True)
 if not ok:
  summary['overall']='FAIL';(out/'summary.json').write_text(json.dumps(summary,indent=2));raise SystemExit(c.stdout)
cmd=[a.iverilog]
if a.ivl_base:cmd+=['-B',a.ivl_base]
c=subprocess.run(cmd+['-V'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(out/'tool_version.txt').write_text(c.stdout)
summary['overall']='SIMULATION_PASS';summary['policy_register_0x6c']='00030001'
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('PASS: PCF CANCELLATION CANDIDATE SIMULATIONS',flush=True)
