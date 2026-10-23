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
from .engines.team_battle import TeamBattle
from .reporting import export, summarize


def execute(scenario, design):
    engine = TeamBattle if scenario['engine']=='team_battle' else Battle
    results,summaries,samples=[],[],[]
    for pair in scenario['pairs']:
        rows=[]
        for i in range(scenario['runs_per_pair']):
            first=i%2
            seed=scenario['seed_base']+pair[0]*1000000+pair[1]*10000+i
            r=engine(design,pair,first,seed,invisible=scenario['invisible']).run(scenario['turn_limit'])
            rows.append(r)
        results.extend(rows);summaries.append(summarize(pair,rows))
        for first in (0,1):
            subset=[r for r in rows if r['first_build']==pair[first]]
            med=statistics.median(r['turns'] for r in subset)
            chosen=min(subset,key=lambda r:abs(r['turns']-med))
            b=engine(design,pair,first,chosen['seed'],detailed=True,invisible=scenario['invisible'])
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
            if scenario['engine'] != 'robin_duel':
                raise ValueError('Mixed duel: update the per-character snapshots; --workbook currently maps Robin only')
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
                      policy=('Normal voluntary attacks only; implemented passive auto-casts/procs remain enabled.' if d.get('action_mode') == 'normal_actions' else 'Ready Hood first; otherwise highest immediate expected damage, including proc/preserved-slot effects; not globally optimal.'),
                      limitations='1vs1 only; mixed-character mode supports normal voluntary actions and implemented passive handlers. 9vs9 Bluetooth retained separately as historical legacy. No arbitrary prose-to-skill inference.',
                      labels=scenario.get('labels',{}),
                      rules=d['rules'],builds=d['build_profiles'])
        if scenario['engine']=='team_battle':
            manifest.update(policy='Main lethal first; Frozen Axe on a legal fresh row for control without overlap; otherwise main-first target and higher immediate expected damage (normal vs direct skill). No swaps/Defend transfers. Not optimal play.',
                limitations='Homogeneous 9vs9 Robin3 vs Bluetooth Striker. Skills SL5 each. Main back-center. Front per column; Any can target protected main. No Connection/Hood unlocked.',
                team_rules='Initial slots2,2,4,4,5; highestAP then random ties. Auto Mark precedes AP/slots, including while Frozen. Highest total effective damage dealer; ties main-first then lowestHP then random. Source-specific Mark +24% does not multiply across Robin casters. Mark applies before own skill damage. Frozen duration3 and DOT3 end-turn ticks; no Frozen overlap; DOT persists after source death. Main death immediately stops combat. Per-actor HP/MP conservation. HP columns show main HP; MP/AP columns show team totals.')
            if d['victory_condition']=='elimination':
                manifest.update(policy='No main. Lowest-current-HP legal primary target, random HP ties. Prioritize likely lethal direct attack; otherwise Frozen on a legal fresh row, otherwise higher immediate damage (normal/direct skill). No swaps/Defend transfers.',
                    limitations='Homogeneous 9vs9 Robin3 vs Bluetooth Striker; full skills at SL5 each. Experiment removes main mechanics entirely. Not optimal play or a general mixed-roster class test.',
                    team_rules='Victory only when all9 opponents die. No position has main priority. Front/Any unchanged. Slots2,2,4,4,5; AP priority then random ties. Auto Mark remains usable while Frozen; highest total effective damage target, ties lowestHP then random. Mark is caster-specific +24% and precedes own damage. No overlapping Frozen; DOT ticks at turn end including application turn and persists after source death. HP/MP/AP columns are team totals.')
        write_json(out/'input_snapshot.json',d)
        export(out,results,summaries,samples,manifest,excel=not args.no_excel)
        for s in summaries:
            a,b=s['pair'];print(f'{a} vs {b}: {s["wins"].get(a,0)}–{s["wins"].get(b,0)}; draws={s["wins"].get(0,0)}; turns={s["mean_turns"]:.3f}')
        print(f'{len(results)} battles in {elapsed:.3f}s (simulation/replays only). Results: {out}')
    except (ValueError,KeyError,FileNotFoundError,FileExistsError) as exc:
        p.exit(2,f'Error: {exc}\n')
