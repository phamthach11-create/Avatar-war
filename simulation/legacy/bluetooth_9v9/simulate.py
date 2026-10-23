"""HISTORICAL Bluetooth build 1 vs build 4 (frozen October 2026 snapshot). Python 3 + openpyxl; see assumptions.json.
Run: python simulate.py --workbook path.xlsx --runs 1000
All amounts are floating point, not rounded per hit.
"""
import argparse, csv, json, math, random, statistics
from collections import Counter
from pathlib import Path
import openpyxl

OUT = Path(__file__).parent
MAIN = 7

def read_design(path):
    w = openpyxl.load_workbook(path, data_only=True)
    s = w['Destroyer class']
    d = {s.cell(r, 1).value: s.cell(r, 2).value for r in range(9, 25)}
    d['skills'] = {name: dict(ap=s.cell(r,2).value, mp=s.cell(r,3).value,
        cd=s.cell(r,4).value, duration=s.cell(r,8).value,
        value=s.cell(r,11).value) for name,r in [('frozen',29),('deadly',31),('connection',32)]}
    d['dot'] = s['K30'].value
    assert d['Attack stun count'] == 0
    assert d['skills']['connection']['duration'] == 2
    assert d['skills']['connection']['cd'] == 2
    d['fortify'] = 0.15  # User confirmed J33: 3% * SL5 overrides stale K33=30%.
    d['resistance'] = s['K34'].value
    assert d['skills']['frozen']['duration'] == 3
    return d

class Battle:
    def __init__(self, d, seed, first, policy='skill_first', detailed=False):
        self.d, self.rng, self.first, self.policy = d, random.Random(seed), first, policy
        self.seed, self.detailed = seed, detailed
        self.teams = [[dict(hp=d['HP'], mp=d['MP'], ap=0., freeze=0, exposure=0,
                           dots={}, link=None, cd_c=d['skills']['connection']['cd'], cd_f=d['skills']['frozen']['cd'],
                           cd_d=d['skills']['deadly']['cd']) for _ in range(9)] for _ in range(2)]
        self.metrics = [Counter(), Counter()]
        self.events, self.turns, self.started = [], [], set()
        self.t = 0
    def record(self, kind, side, pos, target_side='', target='', value=0, detail=''):
        if self.detailed:
            self.events.append([self.t,kind,side+1,pos+1,
                target_side+1 if target_side!='' else '', target+1 if target!='' else '',value,detail])
    def defense(self, side, pos, skill, when=None):
        when=self.t if when is None else when
        u=self.teams[side][pos]
        link=u['link']
        active=link is not None and link['expiry']>=when
        if skill:
            return self.d['Skill Defense']*(.8 if u['exposure']>=when else 1.)+(link['sdef_bonus'] if active else 0)
        base=self.d['Defense']+(700 if side==1 else 0)
        return base+(link['def_bonus'] if active else 0)
    def heal(self, side, pos, fraction, cause):
        u=self.teams[side][pos]
        if u['hp']<=0: return
        raw=self.d['HP']*fraction*1.2
        value=min(raw,self.d['HP']-u['hp'])
        u['hp']+=value
        self.metrics[side]['healing']+=value
        self.metrics[side]['overheal']+=raw-value
        self.record(cause,side,pos,value=value)
    def damage_parts(self, enemy, target, raw, skill, factor, when=None, hp=None):
        """Split FINAL damage: apply target mitigation once, no second mitigation or relay."""
        when=self.t if when is None else when
        hp=[u['hp'] for u in self.teams[enemy]] if hp is None else hp
        link=self.teams[enemy][target]['link']
        active=link is not None and link['expiry']>=when and hp[link['source']]>0
        final=raw*1000/(1000+self.defense(enemy,target,skill,when))*factor
        packets=[(target,final)]
        if active:
            fraction=self.d['skills']['connection']['value']
            packets=[(target,final*(1-fraction)),(link['source'],final*fraction)]
        return packets
    def damage(self, side, pos, enemy, target, raw, skill, factor, cause):
        u=self.teams[enemy][target]
        if u['hp']<=0: return
        self.metrics[side]['raw_damage']+=raw
        self.metrics[side]['after_mitigation_before_penalty']+=raw*1000/(1000+self.defense(enemy,target,skill))
        self.metrics[side]['final_damage_before_overkill']+=raw*1000/(1000+self.defense(enemy,target,skill))*factor
        for j,final in self.damage_parts(enemy,target,raw,skill,factor):
            v=self.teams[enemy][j]
            if v['hp']<=0: continue
            amount=min(final,v['hp'])
            v['hp']-=amount
            self.metrics[side]['damage']+=amount
            self.metrics[side]['damage_'+cause]+=amount
            if j!=target: self.metrics[enemy]['shared_received']+=amount
            self.record(cause if j==target else 'shared_'+cause,side,pos,enemy,j,amount,'HP=%.3f'%v['hp'])
            if v['hp']<=0:
                self.metrics[side]['kills']+=1
                self.record('death',enemy,j)
            if self.ended(): return
    def ended(self):
        return any(team[MAIN]['hp']<=0 for team in self.teams)
    def targets(self, side):
        team=self.teams[side]
        return [i for i,u in enumerate(team) if u['hp']>0 and
                all(team[j]['hp']<=0 for j in range(i%3,i,3))]
    def target(self, side):
        eligible=self.targets(side)
        if MAIN in eligible: return MAIN
        hp=min(self.teams[side][i]['hp'] for i in eligible)
        return self.rng.choice([i for i in eligible if abs(self.teams[side][i]['hp']-hp)<1e-8])
    def beginning(self, side):
        # Start-of-team passives -> AP -> slots. Cooldown, DOT and expiry occur at END.
        self.started.add(side)
        if side==1:
            for i,u in enumerate(self.teams[side]):
                if u['hp']<=0: continue
                self.heal(side,i,.025,'regen')
                if u['cd_c']>0:
                    self.metrics[side]['connection_on_cooldown']+=1
                elif u['mp']>=self.d['skills']['connection']['mp']:
                    u['mp']-=self.d['skills']['connection']['mp']
                    u['cd_c']=self.d['skills']['connection']['cd']
                    self.metrics[side]['connections']+=1
                    self.metrics[side]['mp_used']+=self.d['skills']['connection']['mp']
                    targets=sorted([j for j,v in enumerate(self.teams[side]) if j!=i and v['hp']>0],
                        key=lambda j:(self.teams[side][j]['hp'],j))[:2]
                    # First cast wins. Later casts do not replace or stack links.
                    bonus_def=self.defense(side,i,False)*self.d['fortify']
                    bonus_sdef=self.defense(side,i,True)*self.d['resistance']
                    applied=[]
                    for j in targets:
                        if self.teams[side][j]['link'] is None:
                            self.teams[side][j]['link']=dict(source=i,expiry=self.t+self.d['skills']['connection']['duration']-1,
                                def_bonus=bonus_def,sdef_bonus=bonus_sdef)
                            applied.append(j+1)
                    self.record('connection',side,i,detail='targets=%s; newly linked=%s; expires END turn %s'%([j+1 for j in targets],applied,self.t+self.d['skills']['connection']['duration']-1))
                else: self.metrics[side]['connection_no_mp']+=1
        for i,u in enumerate(self.teams[side]):
            if u['hp']<=0: continue
            u['ap']+=108 if side==0 else 70
            if u['freeze']>=self.t: self.metrics[side]['frozen_character_turns']+=1
    def ending(self):
        # End-turn DOT triggers while effects remain active, including application
        # and last duration turns. Then cooldown recovery; then expiration.
        for a,team in enumerate(self.teams):
            for i,u in enumerate(team):
                if u['hp']<=0: continue
                for key,dot in sorted(u['dots'].items()):
                    if u['hp']<=0: break
                    expiry,source,pos,raw=dot
                    assert expiry>=self.t
                    self.damage(source,pos,a,i,raw,True,1,'dot')
                    self.metrics[source]['dot_ticks']+=1
                    if self.ended(): return
        for a,team in enumerate(self.teams):
            for u in team:
                if u['hp']>0 and a in self.started:
                    for key in ('cd_f','cd_d','cd_c'): u[key]=max(0,u[key]-1)
                u['dots']={k:dot for k,dot in u['dots'].items() if dot[0]>self.t}
                if u['link'] and u['link']['expiry']<=self.t: u['link']=None
                if u['freeze']<=self.t: u['freeze']=0
                if u['exposure']<=self.t: u['exposure']=0
    def choose(self, side, pos):
        u=self.teams[side][pos]; enemy=1-side
        eligible=self.targets(enemy)
        def select(pool):
            if MAIN in pool: return MAIN
            low=min(self.teams[enemy][i]['hp'] for i in pool)
            return self.rng.choice([i for i in pool if abs(self.teams[enemy][i]['hp']-low)<1e-8])
        deadly=side==0 and u['hp']<self.d['HP']/2 and u['cd_d']==0 and u['mp']>=self.d['skills']['deadly']['mp']
        frozen=u['cd_f']==0 and u['mp']>=self.d['skills']['frozen']['mp']
        fresh=[i for i in eligible if all(v['hp']<=0 or v['freeze']<self.t
            for v in self.teams[enemy][i//3*3:i//3*3+3])]
        action='deadly' if deadly else 'frozen' if frozen and fresh else 'normal'
        if frozen and not fresh and not deadly: self.metrics[side]['frozen_overlap_avoided']+=1
        target=select(fresh if action=='frozen' else eligible)
        self.record('choice',side,pos,enemy,target,detail=action)
        return target,action
    def action(self, side, pos):
        u=self.teams[side][pos]; enemy=1-side
        target,action=self.choose(side,pos)
        assert target in self.targets(enemy)
        self.metrics[side]['actions']+=1
        self.metrics[side][action]+=1
        self.record('action',side,pos,enemy,target,detail=action)
        if action=='normal':
            u['ap']-=100
            rate=self.d['Multi-Hit Rate']
            hits=math.floor(rate)+(self.rng.random()<rate%1)
            row,col=divmod(target,3)
            affected=[target]+[row*3+c for c in (col-1,col+1) if 0<=c<3]
            landed=set()
            for h in range(hits):
                for j in affected:
                    if self.teams[enemy][j]['hp']<=0: continue
                    # ACC=100%, EVA=0%, CHC=PEN=0 in both chosen builds.
                    landed.add(j)
                    self.metrics[side]['landed_hits']+=1
                    factor=1 if j==target else (.75 if side==0 else .5)
                    self.damage(side,pos,enemy,j,self.d['Attack']*(1.25 if side==0 else 1),False,factor,'normal')
                    if self.ended(): return
            # One When-attacked roll per target per landed normal Attack, not per hit.
            if enemy==1:
                for j in sorted(landed):
                    if self.teams[enemy][j]['hp']>0 and self.rng.random()<.2:
                        self.metrics[enemy]['heal_procs']+=1
                        self.heal(enemy,j,.005,'attacked_heal')
        else:
            s=self.d['skills'][action]
            u['ap']-=s['ap']; u['mp']-=s['mp']
            self.metrics[side]['mp_used']+=s['mp']
            u['cd_d' if action=='deadly' else 'cd_f']=s['cd']
            affected=[target] if action=='deadly' else list(range(target//3*3,target//3*3+3))
            for j in affected:
                v=self.teams[enemy][j]
                if v['hp']<=0: continue
                self.damage(side,pos,enemy,j,s['value'],True,1,action)
                if self.ended(): return
                if v['hp']>0 and action=='frozen':
                    if v['freeze']>=self.t: self.metrics[side]['overlap_applications']+=1
                    expiry=self.t+s['duration']-1
                    v['freeze']=expiry
                    # Same DOT refreshes/replaces; no unstated stacking.
                    v['dots'][(side,pos)]=(expiry,side,pos,self.d['dot'])
                    self.metrics[side]['max_dot_sources_on_target']=max(self.metrics[side]['max_dot_sources_on_target'],len(v['dots']))
                    if side==1: v['exposure']=expiry
    def run(self, limit=600):
        for self.t in range(1,limit+1):
            side=self.first if self.t%2 else 1-self.first
            self.beginning(side)
            assigned=0
            if not self.ended():
                eligible=[i for i,u in enumerate(self.teams[side]) if u['hp']>0 and u['ap']>=100 and u['freeze']<self.t]
                self.rng.shuffle(eligible)
                eligible.sort(key=lambda i:self.teams[side][i]['ap'],reverse=True)
                cap=2 if self.t<=2 else 4 if self.t<=4 else 5
                slots=eligible[:cap]; assigned=len(slots)
                for i in slots:
                    if self.teams[side][i]['hp']<=0: continue
                    self.action(side,i)
                    if self.ended(): break
            if not self.ended(): self.ending()
            for a,team in enumerate(self.teams):
                for u in team:
                    assert 0<=u['hp']<=self.d['HP']+1e-6 and u['mp']>=0
                expected=9*self.d['HP']-self.metrics[1-a]['damage']+self.metrics[a]['healing']
                assert abs(sum(u['hp'] for u in team)-expected)<1e-5, 'HP conservation'
            if self.detailed:
                self.turns.append([self.t,side+1,assigned,*[sum(u['hp']>0 for u in team) for team in self.teams],
                    *[team[MAIN]['hp'] for team in self.teams],*[sum(u['hp'] for u in team) for team in self.teams],
                    *[sum(u['mp'] for u in team) for team in self.teams]])
            if self.ended(): break
        winner=1 if self.teams[1][MAIN]['hp']<=0 else 4 if self.teams[0][MAIN]['hp']<=0 else 0
        return dict(seed=self.seed,first=1 if self.first==0 else 4,winner=winner,turns=self.t,
                    alive=[sum(u['hp']>0 for u in team) for team in self.teams],
                    hp=[sum(u['hp'] for u in team) for team in self.teams],
                    main_hp=[team[MAIN]['hp'] for team in self.teams],metrics=[dict(m) for m in self.metrics])

def tests(d):
    assert d['fortify']==.15 and d['resistance']==.15
    b=Battle(d,0,1); b.t=1; b.beginning(1)
    assert b.metrics[1]['connections']==0 and b.teams[1][0]['mp']==d['MP']
    b.ending(); assert b.teams[1][0]['cd_c']==1
    b.t=2; b.beginning(0); b.ending(); assert b.teams[1][0]['cd_c']==0
    b.t=3; b.beginning(1)
    assert b.metrics[1]['connections']==9
    link=b.teams[1][1]['link']; assert link['source']==0 and link['expiry']==4
    assert abs(link['def_bonus']-(d['Defense']+700)*.15)<1e-8
    parts=b.damage_parts(1,1,1000,False,1)
    assert len(parts)==2 and parts[0][1]==parts[1][1]
    expected=1000*1000/(1000+b.defense(1,1,False))
    assert abs(sum(n for _,n in parts)-expected)<1e-8
    before=sum(u['hp'] for u in b.teams[1]); b.damage(0,0,1,1,1000,False,1,'test')
    assert abs(before-sum(u['hp'] for u in b.teams[1])-expected)<1e-7
    assert b.metrics[1]['heal_procs']==0
    b.ending(); b.t=4; b.beginning(0)
    assert len(b.damage_parts(1,1,1000,False,1))==2
    b.ending(); assert b.teams[1][1]['link'] is None
    b.t=5; b.beginning(1); assert b.metrics[1]['connections']==18
    # Different casters' DOT stack; duration 3 ticks at END t, t+1, t+2.
    b=Battle(d,0,0); b.t=1; b.started.add(0)
    # Force applications only for testing the engine's source stacking, not AI.
    b.choose=lambda side,pos:(1,'frozen')
    for pos in (0,1):
        b.teams[0][pos]['cd_f']=0; b.action(0,pos)
    victims=[u for u in b.teams[1] if u['dots']]
    assert len(victims)==3 and all(len(u['dots'])==2 and u['freeze']==3 for u in victims)
    assert b.metrics[0]['dot_ticks']==0
    b.ending(); assert b.metrics[0]['dot_ticks']==6 and b.teams[0][0]['cd_f']==5
    b.t=2; b.ending(); assert b.metrics[0]['dot_ticks']==12
    b.t=3; b.ending(); assert b.metrics[0]['dot_ticks']==18
    assert all(not u['dots'] and u['freeze']==0 for u in b.teams[1])
    b.t=4; b.ending(); assert b.metrics[0]['dot_ticks']==18
    # Build 4 applies Exposure (SDEF), not Sunder (DEF).
    b=Battle(d,0,1); b.t=1; b.teams[1][0]['cd_f']=0; b.action(1,0)
    j=next(i for i,u in enumerate(b.teams[0]) if u['exposure'])
    assert abs(b.defense(0,j,True)-d['Skill Defense']*.8)<1e-8
    assert b.defense(0,j,False)==d['Defense']
    b=Battle(d,0,0); b.t=1; b.teams[1][0]['hp']-=10000; b.heal(1,0,.025,'test')
    assert abs(b.metrics[1]['healing']-1552.5)<1e-8
    b.heal(1,0,.005,'test'); assert abs(b.metrics[1]['healing']-1863)<1e-8
    # Actual AI forbids any Frozen overlap within the entire affected row.
    b=Battle(d,0,0); b.t=1
    b.teams[0][0]['cd_f']=0; b.action(0,0)
    b.teams[0][1]['cd_f']=0
    assert b.choose(0,1)[1]=='normal'
    b.teams[1][0]['hp']=0
    assert b.choose(0,1)==(3,'frozen'), 'Choose an un-Frozen legal row if available'
    print('Checks passed: initial/end-turn cooldown; duration; 3 end-turn DOT ticks and source stacking; post-mitigation one-hop sharing; Fortify15%; Exposure; healing.')

def export_csv(name,header,rows):
    with (OUT/(name+'.csv')).open('w',newline='') as f:
        w=csv.writer(f); w.writerow(header); w.writerows(rows)

def main():
    global OUT
    source_dir = Path(__file__).parent
    p=argparse.ArgumentParser(); p.add_argument('--workbook', help='Optional historical workbook; default uses frozen input_stats.json')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--runs',type=int,default=1000,help='TOTAL battles, evenly split between starting orders')
    args=p.parse_args()
    assert 0<args.runs<=1000 and args.runs%2==0
    d=read_design(args.workbook) if args.workbook else json.loads((source_dir/'input_stats.json').read_text())
    tests(d)
    OUT=args.output
    OUT.mkdir(parents=True, exist_ok=False)
    (OUT/'input_stats.json').write_text(json.dumps(d,indent=2))
    results=[]
    for first in (0,1):
        for seed in range(args.runs//2):
            detail=seed==0 and first==0
            b=Battle(d,seed,first,'skill_first',detail)
            result=b.run(); results.append(result)
            if detail:
                (OUT/'sample_result.json').write_text(json.dumps(result,indent=2))
                export_csv('sample_events',['turn','event','side','position','target_side','target_position','amount','detail'],b.events)
                export_csv('sample_turns',['turn','acting_side','slots','build1_alive','build4_alive','build1_main_HP','build4_main_HP','build1_HP','build4_HP','build1_MP','build4_MP'],b.turns)
    assert all(r['metrics'][i].get('overlap_applications',0)==0 for r in results for i in (0,1)), 'AI must never overlap Frozen'
    (OUT/'results.json').write_text(json.dumps(results))
    reports=[]
    for first in (1,4,'both'):
        rs=[r for r in results if first=='both' or r['first']==first]; n=len(rs)
        wins=sum(r['winner']==4 for r in rs); prob=wins/n; z=1.96
        center=(prob+z*z/(2*n))/(1+z*z/n); half=z*math.sqrt(prob*(1-prob)/n+z*z/(4*n*n))/(1+z*z/n)
        reports.append(dict(first=first,n=n,build1_wins=sum(r['winner']==1 for r in rs),build4_wins=wins,
            unresolved=sum(r['winner']==0 for r in rs),build4_wilson95=[center-half,center+half],
            mean_turns=statistics.mean(r['turns'] for r in rs),median_turns=statistics.median(r['turns'] for r in rs),
            mean_alive=[statistics.mean(r['alive'][i] for r in rs) for i in (0,1)],
            mean_metrics=[{key:statistics.mean(r['metrics'][i].get(key,0) for r in rs)
                for key in sorted(set().union(*(r['metrics'][i].keys() for r in rs)))} for i in (0,1)]))
    (OUT/'summary.json').write_text(json.dumps(reports,indent=2))
    print(json.dumps(reports,indent=2),flush=True)

if __name__=='__main__': main()
