"""3x3 extension of the shared duel engine, using the reviewed team targeting rules.

Supports the selected Robin3 and Bluetooth Striker kits. Reuses Fighter, damage
formulas, accuracy/crit expectations and direct Golden casts from robin_duel;
team slot/Front/DOT behavior follows the preserved Bluetooth 9vs9 backend.
"""
import math
from collections import Counter

from .robin_duel import Battle, Fighter


class TeamBattle(Battle):
    def __init__(self, d, builds, first, seed, detailed=False, invisible=False):
        super().__init__(d,builds,first,seed,detailed,invisible)
        self.main=d['main_position']
        self.elimination=d.get('victory_condition','main')=='elimination'
        self.size=d['team_size']
        self.teams=[[Fighter(b,d['combatants'][str(b)]) for _ in range(self.size)] for b in builds]
        for side,team in enumerate(self.teams):
            actor=d['combatants'][str(builds[side])]
            for u in team:
                u.frozen_until=0
                u.marks={}
                u.dots={}
                u.weapon=actor['weapon']
                u.frozen_dot=actor.get('frozen_dot',0)*u.profile['skill_levels'].get('frozen',0)/actor['reference_skill_level']
        self.positions=[0,0]
        self.f=[self.teams[0][0],self.teams[1][0]]
        self.damage_scale=1.

    def focus(self,side,pos,target):
        self.positions[side]=pos;self.positions[1-side]=target
        self.f[side]=self.teams[side][pos];self.f[1-side]=self.teams[1-side][target]
        self.damage_scale=1.

    def alive(self):
        if self.elimination:return all(any(u.hp>0 for u in team) for team in self.teams)
        return all(team[self.main].hp>0 for team in self.teams)

    def log(self,side,event,detail='',raw=0.,damage=0.,effective=0.):
        if self.detailed:
            detail=f'actor_pos={self.positions[side]+1}; target_pos={self.positions[1-side]+1}; '+detail
            self.events.append([self.t,self.builds[side],event,detail,raw,damage,effective,
                *[sum(u.hp for u in team) if self.elimination else team[self.main].hp for team in self.teams],
                sum(u.mp for u in self.teams[0]),sum(u.mp for u in self.teams[1]),
                sum(u.ap for u in self.teams[0]),sum(u.ap for u in self.teams[1])])

    def amp(self,side):
        u,v=self.f[side],self.f[1-side]
        key=(side,self.positions[side])
        return 1+(u.skills['mark']['stat']*u.profile.get('mark_stat_effectiveness',1)
                  if 'mark' in u.skills and self.active(v.marks.get(key,0)) else 0.)

    def damage(self,side,raw,skill,source,penetrate=False):
        u,v=self.f[side],self.f[1-side]
        if v.hp<=0:return
        amp=1. if source=='mark' and not self.d['rules']['mark_amplifies_own_damage'] else self.amp(side)
        final=raw*(1. if penetrate else self.mitigation_factor(side,skill))*amp*self.damage_scale
        actual=min(v.hp,final);v.hp=max(0.,v.hp-final)
        u.metrics['raw_damage']+=raw;u.metrics['final_damage']+=final
        u.metrics['effective_damage']+=actual;u.metrics[source+'_damage']+=actual
        if not self.elimination and self.positions[1-side]==self.main:u.metrics['main_damage']+=actual
        self.log(side,source,'',raw,final,actual)
        if v.hp==0:
            u.metrics['kills']+=1
            self.log(side,'kill','main' if not self.elimination and self.positions[1-side]==self.main else 'avatar')

    def legal_targets(self,enemy,kind):
        team=self.teams[enemy]
        alive=[j for j,u in enumerate(team) if u.hp>0]
        if kind=='Any':return alive
        if kind!='Front':raise ValueError('Unsupported target kind: '+kind)
        return [j for j in alive if all(team[k].hp<=0 for k in range(j%3,j,3))]

    def choose_target(self,enemy,pool):
        if not self.elimination and self.main in pool:return self.main
        low=min(self.teams[enemy][j].hp for j in pool)
        return self.rng.choice([j for j in pool if abs(self.teams[enemy][j].hp-low)<1e-8])

    def normal_area(self,u,target):
        if u.weapon['area']=='Single':return [(target,1.)]
        row,col=divmod(target,3)
        return [(target,1.)]+[(row*3+c,u.weapon['secondary_multiplier']) for c in (col-1,col+1) if 0<=c<3 and row*3+c<self.size]

    def normal(self,side):
        pos,target=self.positions[side],self.positions[1-side]
        u=self.f[side]
        assert target in self.legal_targets(1-side,u.weapon['target'])
        u.ap-=self.d['rules']['normal_attack_ap'];u.metrics['ap_spent']+=self.d['rules']['normal_attack_ap']
        u.metrics['normal_attacks']+=1
        hits=math.floor(u.mhr)+(self.rng.random()<u.mhr%1)
        area=self.normal_area(u,target)  # Fixed center for every hit, including after primary death.
        self.log(side,'normal_attack',f'hits={hits}; primary={target+1}; area={[j+1 for j,_ in area]}')
        for _ in range(hits):
            for j,factor in area:
                if not self.alive():return
                if self.teams[1-side][j].hp<=0:continue
                self.focus(side,pos,j);self.damage_scale=factor
                u.metrics['hit_attempts']+=1
                if self.rng.random()>=self.hit_chance(side):
                    u.metrics['misses']+=1;self.log(side,'miss');continue
                u.metrics['landed_hits']+=1
                crit=self.rng.random()<self.chc(side)
                pen=self.rng.random()<u.pen
                u.metrics['normal_crits']+=int(crit)
                self.damage(side,u.atk*(1+u.cdb if crit else 1),False,'normal',pen)
        self.damage_scale=1.

    def pay(self,side,skill):
        u=self.f[side];s=u.skills[skill]
        assert self.ready(side,skill)
        u.ap-=s['ap'];u.mp-=s['mp'];u.cd[skill]=s['cd']
        u.metrics['ap_spent']+=s['ap'];u.metrics['mp_spent']+=s['mp'];u.metrics[skill+'_casts']+=1
        self.log(side,'cast_'+skill)

    def deadly_allowed(self,u):
        return u.profile.get('deadly_ignore_condition',False) or u.hp<u.max_hp*.5

    def deadly(self,side):
        u=self.f[side]
        assert self.positions[1-side] in self.legal_targets(1-side,'Front') and self.deadly_allowed(u)
        self.pay(side,'deadly')
        self.damage(side,u.skills['deadly']['stat'],True,'deadly')

    def fresh_row(self,enemy,target):
        row=target//3
        return all(v.hp<=0 or not self.active(v.frozen_until) for v in self.teams[enemy][row*3:row*3+3])

    def frozen(self,side):
        pos,target=self.positions[side],self.positions[1-side];u=self.f[side]
        assert target in self.legal_targets(1-side,'Front')
        assert self.fresh_row(1-side,target), 'Frozen Axe overlap is forbidden by this experiment'
        self.pay(side,'frozen');s=u.skills['frozen'];expiry=self.t+s['duration']-1
        for j in range(target//3*3,min(target//3*3+3,self.size)):
            if not self.alive():return
            v=self.teams[1-side][j]
            if v.hp<=0:continue
            self.focus(side,pos,j)
            self.damage(side,s['stat'],True,'frozen_initial')
            if not self.alive():return
            if v.hp>0:
                v.frozen_until=expiry
                v.dots[(side,pos)]=(expiry,u.frozen_dot)
                u.metrics['frozen_targets']+=1
                self.log(side,'apply_frozen',f'expires end T{expiry}')

    def mark(self,side):
        u,v=self.f[side],self.f[1-side]
        assert self.ready(side,'mark') and v.hp>0
        u.mp-=u.skills['mark']['mp'];u.metrics['mp_spent']+=u.skills['mark']['mp']
        u.cd['mark']=u.skills['mark']['cd']
        v.marks[(side,self.positions[side])]=self.t+u.skills['mark']['duration']-1
        u.metrics['mark_casts']+=1
        self.log(side,'auto_cast_mark','source-specific amplification; apply before damage')
        if u.profile.get('mark_damage',False):
            self.damage(side,u.mark_satk*u.profile.get('mark_stat_effectiveness',1),True,'mark')

    def normal_expected(self,side,pos,target,primary_only=False):
        self.focus(side,pos,target);u=self.f[side];score=0.
        for j,factor in self.normal_area(u,target):
            if primary_only and j!=target:continue
            if self.teams[1-side][j].hp<=0:continue
            self.focus(side,pos,j)
            score+=super().expected_normal(side)*factor
        self.focus(side,pos,target)
        return score

    def direct_options(self,side,pos,target):
        self.focus(side,pos,target);u=self.f[side]
        options=[('normal',self.normal_expected(side,pos,target),self.normal_expected(side,pos,target,True))]
        if self.ready(side,'golden'):
            score=self.expected_golden(side);options.append(('golden',score,score))
        if self.ready(side,'deadly') and self.deadly_allowed(u):
            score=u.skills['deadly']['stat']*self.mitigation_factor(side,True)*self.amp(side)
            options.append(('deadly',score,score))
        return options

    def choose_action(self,side,pos):
        u=self.teams[side][pos];enemy=1-side
        pool=self.legal_targets(enemy,u.weapon['target'])
        target=self.choose_target(enemy,pool)
        options=self.direct_options(side,pos,target)
        # Defeating the main ends combat, so don't postpone a likely lethal action for CC.
        lethal=[x for x in options if (self.elimination or target==self.main) and x[2]>=self.teams[enemy][target].hp]
        if lethal:return max(lethal,key=lambda x:x[2])[0],target
        if self.ready(side,'frozen'):
            fresh=[j for j in self.legal_targets(enemy,'Front') if self.fresh_row(enemy,j)]
            if fresh:
                def row_score(j):
                    cells=range(j//3*3,min(j//3*3+3,self.size))
                    return (not self.elimination and self.main in cells,sum(self.teams[enemy][k].hp>0 for k in cells))
                best=max(row_score(j) for j in fresh)
                target=self.choose_target(enemy,[j for j in fresh if row_score(j)==best])
                return 'frozen',target
            u.metrics['frozen_overlap_avoided']+=1
        act=max(options,key=lambda x:x[1])[0]
        self.focus(side,pos,target)
        self.log(side,'choice','; '.join(f'{a}_EV={score:.2f}' for a,score,_ in options))
        return act,target

    def beginning(self,side):
        team=self.teams[side]
        for u in team:
            if u.hp>0:u.started=True;u.metrics['team_turns']+=1
        for pos,u in enumerate(team):
            if not self.alive():return []
            if u.hp<=0 or 'mark' not in u.skills:continue
            self.focus(side,pos,self.main)
            if not self.ready(side,'mark'):continue
            alive=self.legal_targets(1-side,'Any')
            high=max(self.teams[1-side][j].metrics['effective_damage'] for j in alive)
            pool=[j for j in alive if abs(self.teams[1-side][j].metrics['effective_damage']-high)<1e-8]
            target=self.choose_target(1-side,pool)
            self.focus(side,pos,target);self.mark(side)
        if not self.alive():return []
        eligible=[]
        for pos,u in enumerate(team):
            if u.hp<=0:continue
            if not self.active(u.stun_until):u.ap+=u.apr
            if self.active(u.frozen_until):u.metrics['frozen_team_turns']+=1
            if u.ap>=self.d['rules']['slot_ap_requirement'] and not self.active(u.frozen_until) and not self.active(u.stun_until):eligible.append(pos)
            elif u.ap<self.d['rules']['slot_ap_requirement']:u.metrics['ap_ineligible_turns']+=1
        self.rng.shuffle(eligible);eligible.sort(key=lambda j:team[j].ap,reverse=True)
        cap=2 if self.t<=2 else 4 if self.t<=4 else 5
        slots=eligible[:cap]
        for pos in slots:team[pos].metrics['initial_slots']+=1
        return slots

    def ending(self):
        for enemy,team in enumerate(self.teams):
            for j,v in enumerate(team):
                if v.hp<=0:continue
                for (side,pos),(expiry,raw) in sorted(v.dots.items()):
                    if v.hp<=0:break
                    assert expiry>=self.t
                    self.focus(side,pos,j)
                    self.teams[side][pos].metrics['dot_ticks']+=1
                    self.damage(side,raw,True,'frozen_dot')
                    if not self.alive():return
        for team in self.teams:
            for u in team:
                if u.hp>0 and u.started:u.cd={k:max(0,v-1) for k,v in u.cd.items()}
                u.dots={k:v for k,v in u.dots.items() if v[0]>self.t}
                u.marks={k:v for k,v in u.marks.items() if v>self.t}

    def metrics(self,side):
        # Counter.update includes zero entries; total contains all actors, including dead ones.
        total=Counter()
        for u in self.teams[side]:total.update(u.metrics)
        return total

    def check_resources(self):
        for side,team in enumerate(self.teams):
            for u in team:
                assert -1e-7<=u.mp and 0<=u.hp<=u.max_hp
                assert abs(u.max_mp-u.mp-u.metrics['mp_spent'])<1e-6
            lost=sum(u.max_hp-u.hp for u in team)
            assert abs(lost-self.metrics(1-side)['effective_damage'])<1e-5

    def perform_action(self,side,act,target):
        if act=='normal':self.normal(side)
        elif act=='golden':self.golden(side)
        elif act=='deadly':self.deadly(side)
        elif act=='frozen':self.frozen(side)
        else:raise ValueError('Unsupported team action: '+act)

    def run(self,limit=400):
        for self.t in range(1,limit+1):
            side=self.first if self.t%2 else 1-self.first
            slots=self.beginning(side)
            for pos in slots:
                if not self.alive():break
                u=self.teams[side][pos]
                if u.hp<=0 or self.active(u.frozen_until) or self.active(u.stun_until):continue
                act,target=self.choose_action(side,pos)
                self.focus(side,pos,target)
                u.metrics['voluntary_actions']+=1
                self.perform_action(side,act,target)
            if self.alive():self.ending()
            self.check_resources()
            if not self.alive():break
        winner=next((i for i in (0,1) if (all(u.hp<=0 for u in self.teams[1-i]) if self.elimination else self.teams[1-i][self.main].hp<=0)),None)
        totals=[self.metrics(side) for side in (0,1)]
        for side in (0,1):
            totals[side]['survivors']=sum(u.hp>0 for u in self.teams[side])
            totals[side]['team_hp_remaining']=sum(u.hp for u in self.teams[side])
        return dict(build_a=self.builds[0],build_b=self.builds[1],seed=self.seed,
            first_build=self.builds[self.first],winner=0 if winner is None else self.builds[winner],turns=self.t,
            hp_a=sum(u.hp for u in self.teams[0]) if self.elimination else self.teams[0][self.main].hp,
            hp_b=sum(u.hp for u in self.teams[1]) if self.elimination else self.teams[1][self.main].hp,
            mp_a=sum(u.mp for u in self.teams[0]),mp_b=sum(u.mp for u in self.teams[1]),
            metrics_a=dict(totals[0]),metrics_b=dict(totals[1]))
