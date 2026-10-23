"""Robin-compatible duel mechanics; numerical build choices live in JSON.

This backend supports normal attacks, Golden damage/procs, Hood and Mark.
A new skill mechanic requires an explicit handler, not guessing from Excel prose.
"""
import math
import random
from collections import Counter

class Fighter:
    def __init__(self, build, d):
        self.build = build
        self.profile = d['build_profiles'][str(build)]
        p = self.profile
        def stat(name):
            return (d[name] + p.get('base_bonuses', {}).get(name, 0)) * (1 + p.get('stat_modifiers', {}).get(name, 0))
        self.hp, self.mp, self.ap = stat('HP'), stat('MP'), d['rules']['starting_ap']
        self.max_hp, self.max_mp = self.hp, self.mp
        self.atk, self.mhr, self.acc, self.eva = [stat(k) for k in ('Attack', 'Multi-Hit Rate', 'Accuracy', 'Evasion')]
        self.defense, self.sdef, self.apr = [stat(k) for k in ('Defense','Skill Defense','AP Recovery')]
        self.base_chc, self.cdb, self.pen, self.threshold = [stat(k) for k in ('Critical Hit Chance','Critical Damage Bonus','Penetration chance','Stun Threshold')]
        self.skills = {key: dict(d['skills'][key]) for key in p['skills']}
        for key, spec in self.skills.items():
            spec['stat'] *= p['skill_levels'][key] / d['reference_skill_level']
        self.golden_satk = self.skills['golden']['stat'] * (1 + p.get('golden_satk_modifier', 0))
        self.mark_satk = d['mark_satk'] * p['skill_levels'].get('mark', 0) / d['reference_skill_level']
        self.hood_cd = d['skills']['hood']['cd'] + p.get('hood_cd_delta', 0)
        if 'hood' in self.skills:
            self.skills['hood']['cd'] = self.hood_cd
        if 'mark' in self.skills:
            self.skills['mark']['mp'] = p.get('mark_mana_cost', self.skills['mark']['mp'])
        self.cd = {key: spec['cd'] for key, spec in self.skills.items()}
        self.started = False
        self.hood_until = 0
        self.defend_until = 0
        self.mark_until = 0
        self.stun_until = 0
        self.stacks = 0
        self.stack_until = 0
        self.stack_last_turn = -1
        self.metrics = Counter()


class Battle:
    def __init__(self, d, builds, first, seed, detailed=False, invisible=False):
        self.d, self.builds, self.first, self.seed = d, builds, first, seed
        self.rng = random.Random(seed)
        self.f = [Fighter(b, d) for b in builds]
        self.t = 0
        self.events = []
        self.turns = []
        self.detailed = detailed
        self.invisible = invisible

    def log(self, side, event, detail='', raw=0., damage=0., effective=0.):
        if self.detailed:
            self.events.append([self.t, self.builds[side], event, detail, raw, damage, effective,
                                self.f[0].hp, self.f[1].hp, self.f[0].mp, self.f[1].mp,
                                self.f[0].ap, self.f[1].ap])

    def alive(self):
        return all(u.hp > 0 for u in self.f)

    def active(self, expiry):
        return expiry > 0 and expiry >= self.t

    def targetable(self, side):
        return self.f[1-side].hp > 0 and (not self.invisible or not self.active(self.f[1-side].hood_until))

    def chc(self, side):
        return self.f[side].base_chc * (1 + self.f[side].skills['hood']['stat']
                     if 'hood' in self.f[side].skills and self.active(self.f[side].hood_until) else 1)

    def hit_chance(self, side):
        return max(0., min(1., self.f[side].acc - self.f[1-side].eva))

    def amp(self, side):
        return 1 + (self.f[side].skills['mark']['stat'] * self.f[side].profile.get('mark_stat_effectiveness', 1)
                    if 'mark' in self.f[side].skills and self.active(self.f[1-side].mark_until) else 0.)

    def mitigation_factor(self, side, skill=False):
        target = self.f[1-side]
        stat = target.sdef if skill else target.defense
        if self.active(target.defend_until):
            stat *= self.d['rules']['defend_multiplier']
        k = self.d['rules']['power_constant']
        return k / (k + stat)

    def ready(self, side, skill):
        u = self.f[side]
        mana = u.skills[skill]['mp'] if skill in u.skills else math.inf
        return skill in u.cd and u.cd[skill] == 0 and u.mp >= mana

    def damage(self, side, raw, skill, source, penetrate=False):
        u, v = self.f[side], self.f[1-side]
        amplification = 1. if source == 'mark' and not self.d['rules']['mark_amplifies_own_damage'] else self.amp(side)
        final = raw * (1. if penetrate else self.mitigation_factor(side, skill)) * amplification
        effective = min(v.hp, final)
        v.hp = max(0., v.hp - final)
        u.metrics['raw_damage'] += raw
        u.metrics['final_damage'] += final
        u.metrics['effective_damage'] += effective
        u.metrics[source + '_damage'] += effective
        self.log(side, source, '', raw, final, effective)

    def add_stun(self, side):
        v = self.f[1-side]
        if v.hp <= 0 or self.active(v.stun_until) or v.stack_last_turn == self.t:
            return
        v.stacks += self.f[side].profile.get('golden_stun_count', 0)
        v.stack_until = self.t + self.d['rules']['stun_count_duration'] - 1
        v.stack_last_turn = self.t
        self.f[side].metrics['stun_stacks_applied'] += 1
        self.log(side, 'stun_count', str(v.stacks))
        if v.stacks >= v.threshold:
            v.stacks, v.stack_until = 0, 0
            v.stun_until = self.t + self.d['rules']['stun_duration'] - 1
            self.f[side].metrics['stuns'] += 1
            self.log(side, 'stun', 'expires end T%d' % v.stun_until)

    def golden(self, side, triggered=False):
        assert self.ready(side, 'golden') and self.targetable(side)
        u = self.f[side]
        s = u.skills['golden']
        u.mp -= s['mp']
        u.metrics['mp_spent'] += s['mp']
        if not triggered:
            u.ap -= s['ap']
            u.metrics['ap_spent'] += s['ap']
            u.metrics['golden_active_casts'] += 1
        else:
            u.metrics['golden_triggered_casts'] += 1
            u.ap -= self.d['rules']['triggered_golden_ap']
            u.metrics['ap_spent'] += self.d['rules']['triggered_golden_ap']
        u.cd['golden'] = s['cd']
        crit = u.profile.get('golden_crit', False) and self.rng.random() < self.chc(side)
        if crit:
            u.metrics['golden_crits'] += 1
        self.log(side, 'cast_golden', 'triggered=%s; critical=%s; AP_cost=%s' % (triggered, crit, self.d['rules']['triggered_golden_ap'] if triggered else s['ap']))
        self.damage(side, u.golden_satk * (1 + u.cdb if crit else 1),
                    True, 'golden_triggered' if triggered else 'golden_active')
        if self.alive() and u.profile.get('golden_stun_count', 0) > 0:
            self.add_stun(side)
        # Preserving the slot does not reset the skill cooldown or refund costs.
        keep = self.alive() and not triggered and u.profile.get('golden_keep_slot_chance', 0) > 0 and self.rng.random() < u.profile['golden_keep_slot_chance']
        if keep:
            u.metrics['slots_preserved'] += 1
            self.log(side, 'slot_preserved')
        return keep

    def normal(self, side):
        assert self.targetable(side)
        u = self.f[side]
        u.ap -= self.d['rules']['normal_attack_ap']
        u.metrics['ap_spent'] += self.d['rules']['normal_attack_ap']
        u.metrics['normal_attacks'] += 1
        hits = math.floor(u.mhr) + (self.rng.random() < u.mhr % 1)
        self.log(side, 'normal_attack', 'generated_hits=%d' % hits)
        for _ in range(hits):
            if not self.alive():
                break
            u.metrics['hit_attempts'] += 1
            if self.rng.random() >= self.hit_chance(side):
                u.metrics['misses'] += 1
                self.log(side, 'miss')
                continue
            u.metrics['landed_hits'] += 1
            crit = self.rng.random() < self.chc(side)
            pen = self.rng.random() < u.pen
            u.metrics['normal_crits'] += int(crit)
            self.damage(side, u.atk * (1 + u.cdb if crit else 1), False, 'normal', pen)
            if not self.alive():
                break
            if u.profile.get('on_hit_golden_chance', 0) > 0 and self.ready(side, 'golden'):
                u.metrics['golden_trigger_checks'] += 1
                if self.rng.random() < u.profile['on_hit_golden_chance']:
                    self.golden(side, triggered=True)

    def hood(self, side):
        assert self.ready(side, 'hood')
        u = self.f[side]
        s = u.skills['hood']
        u.mp -= s['mp']
        u.ap -= s['ap']
        refund = u.profile.get('hood_ap_refund', 0)
        u.ap += refund
        u.metrics['ap_spent'] += s['ap']
        u.metrics['ap_restored'] += refund
        u.metrics['mp_spent'] += s['mp']
        u.metrics['hood_casts'] += 1
        u.metrics['extra_slots_granted'] += 1
        u.hood_until = self.t + s['duration'] - 1
        u.cd['hood'] = u.hood_cd
        self.log(side, 'cast_hood', 'expires end T%d; grants 1 slot; AP refund=%d' % (u.hood_until, refund))

    def mark(self, side):
        u = self.f[side]
        assert 'mark' in u.skills and self.ready(side, 'mark') and self.targetable(side)
        u.cd['mark'] = u.skills['mark']['cd']
        u.mp -= u.skills['mark']['mp']
        u.metrics['mp_spent'] += u.skills['mark']['mp']
        self.f[1-side].mark_until = self.t + u.skills['mark']['duration'] - 1
        u.metrics['mark_casts'] += 1
        self.log(side, 'auto_cast_mark', 'AP=0; MP=%s; mark applied before skill damage' % u.skills['mark']['mp'])
        if u.profile.get('mark_damage', False):
            self.damage(side, u.mark_satk * u.profile.get('mark_stat_effectiveness', 1), True, 'mark')

    def expected_normal(self, side):
        u = self.f[side]
        q = self.hit_chance(side)
        mitigation = ((1-u.pen) * self.mitigation_factor(side)
                      + u.pen)
        dmg = u.atk * u.mhr * q * (1 + self.chc(side)*u.cdb) * mitigation * self.amp(side)
        if u.profile.get('on_hit_golden_chance', 0) > 0 and self.ready(side, 'golden'):
            n, frac = math.floor(u.mhr), u.mhr % 1
            failure = (1-q*u.profile['on_hit_golden_chance'])**n * (1-frac + frac*(1-q*u.profile['on_hit_golden_chance']))
            dmg += (1-failure)*self.expected_golden(side)
        return dmg

    def expected_golden(self, side):
        u = self.f[side]
        crit = 1 + self.chc(side)*u.cdb if u.profile.get('golden_crit', False) else 1
        return u.golden_satk * crit * self.mitigation_factor(side, True) * self.amp(side)

    def choose(self, side):
        u = self.f[side]
        # Use available defensive/self buff without overwriting its duration.
        # This explicit AI policy is not a claim of globally optimal play.
        if self.d['rules']['cast_hood_when_ready'] and 'hood' in u.skills and not self.active(u.hood_until) and self.ready(side, 'hood'):
            return 'hood'
        if not self.targetable(side):
            return 'defend'
        normal = self.expected_normal(side)
        golden = -1.
        if self.ready(side, 'golden'):
            golden = self.expected_golden(side)
            if u.profile.get('golden_keep_slot_chance', 0) > 0:
                # After a preserved slot, Golden is on cooldown; normal is available.
                # Ignore overkill in this selection score; actual death stops all actions.
                golden += u.profile['golden_keep_slot_chance'] * (self.expected_normal(side))
        self.log(side, 'choice', 'normal_EV=%.3f; golden_EV=%.3f' % (normal, golden))
        return 'golden' if golden > normal else 'normal'

    def start(self, side):
        u = self.f[side]
        u.started = True
        u.metrics['team_turns'] += 1
        if 'mark' in u.skills and self.ready(side, 'mark'):
            if self.targetable(side):
                self.mark(side)
            else:
                u.metrics['mark_blocked_invisible'] += 1
                self.log(side, 'mark_blocked_invisible')
        if not self.alive():
            return False
        if self.active(u.stun_until):
            # Status sets Character Base APR=0; this Robin has no item APR.
            u.metrics['stunned_team_turns'] += 1
            self.log(side, 'stunned_no_ap_no_slot')
            return False
        u.ap += u.apr
        if u.ap < self.d['rules']['slot_ap_requirement']:
            u.metrics['ap_ineligible_turns'] += 1
            self.log(side, 'no_slot_low_ap')
            return False
        u.metrics['initial_slots'] += 1
        return True

    def end(self):
        for u in self.f:
            if u.hp > 0 and u.started:
                u.cd = {key: max(0, value-1) for key, value in u.cd.items()}
            if u.stack_until <= self.t:
                u.stacks = 0
                u.stack_until = 0
        # Effect expiry is represented by inclusive until timestamps.

    def run(self, limit=400):
        for self.t in range(1, limit+1):
            side = self.first if self.t % 2 else 1-self.first
            slot = self.start(side)
            guard = 0
            while slot and self.alive():
                guard += 1
                assert guard <= 1000, 'Non-terminating slot loop; check zero-cost/cooldown configuration'
                u = self.f[side]
                act = self.choose(side)
                u.metrics['voluntary_actions'] += 1
                slot = False
                if act == 'hood':
                    self.hood(side)
                    slot = True
                elif act == 'normal':
                    self.normal(side)
                elif act == 'golden':
                    slot = self.golden(side)
                else:
                    # One character: defend has no transfer recipient, ending slot.
                    u.ap -= self.d['rules']['defend_ap']
                    u.metrics['ap_spent'] += self.d['rules']['defend_ap']
                    u.metrics['defends'] += 1
                    u.metrics['no_target_slots'] += 1
                    u.defend_until = self.t + 1
                    self.log(side, 'defend', 'enemy Invisible; expires before next own turn')
            if self.detailed:
                self.turns.append([self.t, self.builds[side], *[
                    value for u in self.f for value in (u.hp, u.mp, u.ap, u.cd.get('golden', 0),
                     u.cd.get('hood', u.cd.get('mark', 0)), u.hood_until, u.stacks, u.stun_until)]])
            if not self.alive():
                break
            self.end()
        winner = next((i for i in (0, 1) if self.f[1-i].hp <= 0), None)
        result = dict(build_a=self.builds[0], build_b=self.builds[1], seed=self.seed,
                      first_build=self.builds[self.first], winner=0 if winner is None else self.builds[winner],
                      turns=self.t, hp_a=self.f[0].hp, hp_b=self.f[1].hp,
                      mp_a=self.f[0].mp, mp_b=self.f[1].mp,
                      metrics_a=dict(self.f[0].metrics), metrics_b=dict(self.f[1].metrics))
        for u in self.f:
            assert u.mp >= -1e-8 and 0 <= u.hp <= u.max_hp
            assert abs(u.mp - (u.max_mp - u.metrics['mp_spent'])) < 1e-6
        return result

