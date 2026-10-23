import unittest

from simulation.configuration import load_scenario
from simulation.engines.team_battle import TeamBattle


class TeamBattleTests(unittest.TestCase):
    def setUp(self):
        self.scenario,self.d=load_scenario('robin3_bluetooth_9v9')
        self.b=TeamBattle(self.d,(3,4),0,91)
        self.b.t=1

    def test_front_per_column_and_any_protected_main(self):
        b=self.b
        self.assertEqual(b.legal_targets(1,'Front'),[0,1,2])
        self.assertIn(7,b.legal_targets(1,'Any'))
        b.teams[1][1].hp=0
        self.assertEqual(b.legal_targets(1,'Front'),[0,2,4])
        b.teams[1][4].hp=0
        self.assertIn(7,b.legal_targets(1,'Front'))

    def test_slots_are_limited_and_freeze_does_not_block_ap(self):
        b=self.b
        self.assertEqual(len(b.beginning(0)),2)
        for u in b.teams[0]:u.cd={k:99 for k in u.cd};u.frozen_until=3
        b.t=3
        self.assertEqual(b.beginning(0),[])
        self.assertEqual(b.teams[0][0].ap,200)
        b.t=5
        self.assertEqual(len(b.beginning(0)),5)

    def test_marks_are_source_specific_not_ninefold_damage(self):
        b=self.b
        target=b.teams[1][0]
        b.focus(0,0,0);b.f[0].cd['mark']=0;b.mark(0)
        self.assertAlmostEqual(b.amp(0),1.24)
        b.focus(0,1,0);self.assertEqual(b.amp(0),1)
        b.f[0].cd['mark']=0;b.mark(0)
        self.assertEqual(len(target.marks),2)
        self.assertAlmostEqual(b.amp(0),1.24)
        b.focus(0,0,0);self.assertAlmostEqual(b.amp(0),1.24)

    def test_passive_works_while_frozen_and_targets_top_damage(self):
        b=self.b;b.t=3
        b.teams[1][5].metrics['effective_damage']=100
        for u in b.teams[0]:u.frozen_until=5
        b.teams[0][0].cd['mark']=0
        b.beginning(0)
        self.assertIn((0,0),b.teams[1][5].marks)
        self.assertEqual(b.teams[0][0].metrics['mark_casts'],1)
        self.assertEqual(b.teams[0][0].metrics['initial_slots'],0)

    def test_deadly_at_full_health_pays_300_ap(self):
        b=self.b;b.focus(1,0,0);u=b.f[1];u.cd['deadly']=0;u.ap=108
        b.deadly(1)
        self.assertEqual(u.ap,-192)
        self.assertEqual(u.mp,u.max_mp-6000)
        self.assertAlmostEqual(b.teams[0][0].max_hp-b.teams[0][0].hp,16800*1000/1880)

    def test_frozen_duration_dot_and_no_overlap(self):
        b=self.b;b.focus(1,0,0);u=b.f[1];u.cd['frozen']=0
        b.frozen(1)
        self.assertTrue(all(v.frozen_until==3 for v in b.teams[0][:3]))
        self.assertFalse(b.fresh_row(0,0))
        b.focus(1,1,0);b.f[1].cd['frozen']=0
        self.assertNotEqual(b.choose_action(1,1)[0],'frozen')
        b.ending();self.assertEqual(u.metrics['dot_ticks'],3)
        b.t=2;b.ending();b.t=3;b.ending()
        self.assertEqual(u.metrics['dot_ticks'],9)
        self.assertTrue(all(not v.dots for v in b.teams[0][:3]))
        b.t=4;self.assertTrue(b.fresh_row(0,0))

    def test_dot_survives_source_death(self):
        b=self.b;b.focus(1,0,0);b.f[1].cd['frozen']=0;b.frozen(1)
        b.teams[1][0].hp=0
        before=b.teams[0][0].hp;b.ending()
        self.assertLess(b.teams[0][0].hp,before)

    def test_secondary_hits_continue_after_primary_death(self):
        b=self.b;b.focus(1,0,1);u=b.f[1];u.mhr=2;u.acc=10
        b.teams[0][1].hp=1
        before=b.teams[0][0].hp
        b.normal(1)
        self.assertEqual(b.teams[0][1].hp,0)
        self.assertAlmostEqual(before-b.teams[0][0].hp,2*u.atk*1000/1870*.5)

    def test_main_death_stops_remaining_hits(self):
        b=self.b;b.focus(0,0,7);u=b.f[0];u.mhr=3
        b.teams[1][7].hp=1;b.normal(0)
        self.assertFalse(b.alive())
        self.assertEqual(u.metrics['hit_attempts'],1)

    def test_seed_replay_and_team_conservation(self):
        a=TeamBattle(self.d,(3,4),0,123,detailed=True).run()
        b=TeamBattle(self.d,(3,4),0,123).run()
        self.assertEqual(a,b)
        self.assertAlmostEqual(a['metrics_a']['effective_damage'],9*51750-a['metrics_b']['team_hp_remaining'])
        self.assertAlmostEqual(a['metrics_b']['effective_damage'],9*36250-a['metrics_a']['team_hp_remaining'])

    def test_elimination_has_no_main_priority_or_main_death_stop(self):
        _,d=load_scenario('robin3_bluetooth_9v9_elimination')
        b=TeamBattle(d,(3,4),0,91);b.t=1
        b.teams[1][2].hp=100
        self.assertEqual(b.choose_target(1,b.legal_targets(1,'Any')),2)
        b.teams[1][7].hp=1
        b.focus(0,0,7);b.normal(0)
        self.assertEqual(b.teams[1][7].hp,0)
        self.assertTrue(b.alive())
        for u in b.teams[1]:u.hp=0
        self.assertFalse(b.alive())

    def test_elimination_run_ends_with_entire_team_dead(self):
        _,d=load_scenario('robin3_bluetooth_9v9_elimination')
        b=TeamBattle(d,(3,4),0,123,detailed=True)
        r=b.run()
        self.assertIn(r['winner'],(3,4))
        losing='b' if r['winner']==3 else 'a'
        self.assertEqual(r['metrics_'+losing]['survivors'],0)
        self.assertEqual(r['hp_'+losing],0)
        for side in ('a','b'):
            self.assertEqual(r['hp_'+side],r['metrics_'+side]['team_hp_remaining'])
        self.assertEqual(b.events[-1][7:9],[r['hp_a'],r['hp_b']])


if __name__=='__main__':unittest.main()
