"""Reusable one-match mixed-roster runner (no automatic balance batch).

python -m simulation.mixed_run --output simulation/results/mixed_automata_42
"""
import argparse,csv,hashlib,json
from pathlib import Path
from .mixed_workbook import load_roster
from .engines.mixed_battle import MixedBattle

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--workbook',default='data/excel/Thiết kế game.xlsx');parser.add_argument('--scenario',default='simulation/scenarios/mixed_mirror_automata.json');parser.add_argument('--output',required=True);parser.add_argument('--seed',type=int);args=parser.parse_args()
 scenario=json.loads(Path(args.scenario).read_text());data=load_roster(args.workbook,scenario)
 out=Path(args.output);out.mkdir(parents=True,exist_ok=False)
 b=MixedBattle(data,first=scenario['first_team'],seed=args.seed if args.seed is not None else scenario['seed']);result=b.run(scenario['max_global_turns'])
 notes=[
 'Python extension of TeamBattle, not the local-only Godot demo. One seeded mirror match, not a win-rate estimate.',
 'Each build includes its spec unlock and uses six passive points. Joan means S1.1.1 plus all S1.2.1–S1.2.4.',
 'Joan SP: Holy Blade4, Holy Guard5, Maiden Care5. Other non-Leonardo skills5. Leonardo6: Piercing5/Bombard5; Leonardo8: Mona10/Piercing7, Vitruvian0. Unlock level1 counts within allocated SP.',
 'Grand Battery auto-casts at allied team-turn start: user-confirmed for this test.',
 'Mona is selected when a living, non-Immune ally has current HP below50% MaxHP and the caster can act/pay. Otherwise missing summons take priority. Holy Guard uses the same threshold.',
 'Robin uses Hood when available and not already Invisible, then its granted slot for normal attack. Golden Arrow is only triggered by its selected 5% When Hitting node; costs MP/cooldown but no AP.',
 'Normal targeting prefers an exposed main, then lowest-current-HP legal target. Automata choose random legal targets. Offensive skills compare a bounded immediate/DOT estimate, with Frozen control priority, no duplicate Frozen and no swap/Defend AI. This is not an optimal strategy search.',
 'Existing automatons attack only at allied team-turn start, after their summoning turn, and persist for the rest of battle including owner death, as the summon descriptions specify battle-long duration and no despawn condition.',
 'Automatons snapshot owner Base Attack at summon; inherit no other owner stats. Baseline one hit, hit check at100% Accuracy against target Evasion; CHC/CDB/PEN0 unless selected machine nodes add them. Inventor upgrades give MHR112%, CHC12%, ATK Effectiveness110%, both stun1; no CDB means those critical rolls do not increase damage.',
 'No extra summon AP/MP costs, HP, board slots or targeting were invented. Machines are persistent skill entities, not additional formation characters.',
 'Immunity follows current status wording: blocks effects applied by skill casts (including friendly casts) and negative statuses. Existing DOT still ticks.',
 'Same-status/same-skill-or-node duplicates never replace or refresh, regardless of caster; different DOT skills can coexist. Stun Count is the explicit shared stacking/refresh exception.',
 'No skill values were silently corrected except interpreting cached Mona SL5 Heal4135 via its intended linear SL scaling; workbook formula text contains50%% and is retained in the input snapshot.'
 ]
 digest=hashlib.sha256()
 for p in [Path(__file__),Path(__file__).parent/'mixed_workbook.py',Path(__file__).parent/'engines/mixed_battle.py',Path(__file__).parent/'engines/team_battle.py',Path(__file__).parent/'engines/robin_duel.py']:digest.update(p.read_bytes())
 manifest={'seed':b.seed,'first_team':'AB'[b.first],'workbook_sha256':data['workbook_sha256'],'engine_sha256':digest.hexdigest(),'notes':notes}
 data['notes']=notes
 log={'schema_version':1,'implementation':'Python MixedBattle','manifest':manifest,'initial_state':b.initial,'events':b.events,'turn_end_states':b.turns,'final_state':b.snapshot(),'result':result}
 for name,obj in [('input_snapshot.json',data),('battle_log.json',log),('result.json',result),('manifest.json',manifest)]:
  (out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2))
 rows=[]
 for side,team in enumerate(b.teams):
  for i,u in enumerate(team):rows.append({'team':'AB'[side],'slot':i+1,'character':u.p['name'],'hp':round(u.hp,2),'damage':round(u.metrics['effective_damage'],2),'healing':round(u.metrics['healing'],2),'automaton_damage':round(u.metrics['automaton_Piercer_damage']+u.metrics['automaton_Devastator_damage'],2),'mp_left':round(u.mp,2),'skills':json.dumps({k.removesuffix('_casts'):v for k,v in u.metrics.items() if k.endswith('_casts')},ensure_ascii=False)})
 with (out/'units.csv').open('w',newline='',encoding='utf-8-sig') as f:
  wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
 interesting=[e for e in b.events if e['event'] in ['summon','death'] or e['event']=='cast' and e['skill']=='Mona Lisa']
 (out/'milestones.json').write_text(json.dumps(interesting,ensure_ascii=False,indent=2))
 report=['# Mixed 9vs9 — Automaton test',f"Seed {b.seed}; A đi trước; main slot5. Kết quả: đội {'AB'[result['winner']-1] if result['winner'] else 'hòa'}, global turn {result['turns']}.",'','| Team | Slot | Character | HP còn lại | Damage | Heal | Automaton damage |','|---|---:|---|---:|---:|---:|---:|']
 for r in rows:report.append('| '+ ' | '.join(str(r[k]) for k in ['team','slot','character','hp','damage','healing','automaton_damage'])+' |')
 report+=['','## Skill allocation and policies']+['- '+s for s in notes]
 (out/'report.md').write_text('\n'.join(report))
 print(json.dumps({'result':result,'units':rows,'milestones':interesting},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
