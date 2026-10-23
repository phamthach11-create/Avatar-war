"""One entry point for repeatable experiments; paths are relative to the package."""
import argparse
import hashlib
import json
import platform
import statistics
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from .configuration import ROOT, import_excel, load_scenario, validate_design, write_json
from .engines.robin_duel import Battle
from .reporting import export, summarize


def execute(scenario, design):
    results,summaries,samples=[],[],[]
    for pair in scenario['pairs']:
        rows=[]
        for i in range(scenario['runs_per_pair']):
            first=i%2
            seed=scenario['seed_base']+pair[0]*1000000+pair[1]*10000+i
            r=Battle(design,pair,first,seed,invisible=scenario['invisible']).run(scenario['turn_limit'])
            rows.append(r)
        results.extend(rows);summaries.append(summarize(pair,rows))
        for first in (0,1):
            subset=[r for r in rows if r['first_build']==pair[first]]
            med=statistics.median(r['turns'] for r in subset)
            chosen=min(subset,key=lambda r:abs(r['turns']-med))
            b=Battle(design,pair,first,chosen['seed'],detailed=True,invisible=scenario['invisible'])
            if b.run(scenario['turn_limit']) != chosen:raise RuntimeError('Replay mismatch')
            samples.append((f'{pair[0]}v{pair[1]}_first{pair[first]}',b))
    return results,summaries,samples


def main():
    p=argparse.ArgumentParser(description='Avatar War reusable simulation workspace')
    sub=p.add_subparsers(dest='command',required=True)
    run=sub.add_parser('run');run.add_argument('scenario',nargs='?',default='robin_duels')
    run.add_argument('--runs',type=int);run.add_argument('--seed',type=int)
    run.add_argument('--invisible',choices=['on','off']);run.add_argument('--pair',nargs=2,type=int)
    run.add_argument('--workbook',type=Path,help='Import reviewed numeric changes into this run only')
    run.add_argument('--output',type=Path);run.add_argument('--no-excel',action='store_true')
    imp=sub.add_parser('import-excel');imp.add_argument('--workbook',required=True,type=Path)
    imp.add_argument('--output',type=Path,default=ROOT/'data/characters/robin_hood.json')
    args=p.parse_args()
    try:
        scenario,d=load_scenario(getattr(args,'scenario','robin_duels'))
        if args.command=='import-excel':
            fresh=import_excel(args.workbook)
            check=dict(fresh,build_profiles=d['build_profiles'],rules=d['rules']);validate_design(check,scenario)
            write_json(args.output,fresh);print(f'Updated snapshot: {args.output}');return
        for arg,key in [('runs','runs_per_pair'),('seed','seed_base')]:
            if getattr(args,arg) is not None:scenario[key]=getattr(args,arg)
        if args.invisible is not None:scenario['invisible']=args.invisible=='on'
        if args.pair:scenario['pairs']=[args.pair]
        if args.workbook:
            d=dict(import_excel(args.workbook),build_profiles=d['build_profiles'],rules=d['rules'])
        validate_design(d,scenario)
        # A run directory is never overwritten, even when two runs start together.
        out=args.output or ROOT/'results'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
        out.mkdir(parents=True,exist_ok=False)
        start=time.perf_counter()
        results,summaries,samples=execute(scenario,d)
        elapsed=time.perf_counter()-start
        try: revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
        except (OSError,subprocess.CalledProcessError):revision='unknown'
        code_hash=hashlib.sha256()
        for path in sorted(ROOT.rglob('*.py')):
            if 'results' not in path.parts:code_hash.update(str(path.relative_to(ROOT)).encode());code_hash.update(path.read_bytes())
        manifest=dict(scenario=scenario,character=d['id'],source_excel_sha256=d['source_sha256'],
                      python=platform.python_version(),git_revision=revision,python_source_sha256=code_hash.hexdigest(),
                      simulation_seconds=elapsed,actual_battles=len(results),
                      policy='Ready Hood first; otherwise highest immediate expected damage, including proc/preserved-slot effects; not globally optimal.',
                      limitations='robin_duel backend: Robin-compatible 1vs1 only. 9vs9 Bluetooth retained separately as historical legacy. No arbitrary prose-to-skill inference.',
                      rules=d['rules'],builds=d['build_profiles'])
        write_json(out/'input_snapshot.json',d)
        export(out,results,summaries,samples,manifest,excel=not args.no_excel)
        for s in summaries:
            a,b=s['pair'];print(f'{a} vs {b}: {s["wins"].get(a,0)}–{s["wins"].get(b,0)}; draws={s["wins"].get(0,0)}; turns={s["mean_turns"]:.3f}')
        print(f'{len(results)} battles in {elapsed:.3f}s (simulation/replays only). Results: {out}')
    except (ValueError,KeyError,FileNotFoundError,FileExistsError) as exc:
        p.exit(2,f'Error: {exc}\n')
