import copy,json,unittest
from pathlib import Path
from simulation.mixed_workbook import load_roster
from simulation.engines.mixed_battle import MixedBattle
ROOT=Path(__file__).resolve().parents[2]
class MixedTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.data=load_roster(ROOT/'data/excel/Thiết kế game.xlsx',json.loads((ROOT/'simulation/scenarios/mixed_mirror_automata.json').read_text()))
 def setUp(self):self.b=MixedBattle(self.data);self.b.t=1
 def test_builds_budget_and_import(self):
  r=self.data['roster'];self.assertEqual([len(x['nodes']) for x in r],[6]*9)
  self.assertEqual(r[7]['stats']['sp'],17);self.assertEqual(r[7]['skills']['Mona Lisa']['level'],10)
  self.assertAlmostEqual(r[7]['skills']['Summon Piercing Automaton']['stat'],1.2)
  self.assertAlmostEqual(r[0]['stats']['mhr'],1.37);self.assertAlmostEqual(r[0]['stats']['chc'],.4)
  self.assertAlmostEqual(r[0]['extras']['secondary_penalty_delta'],-.3)
  self.assertAlmostEqual(r[4]['stats']['atk'],2647.12092130518)
  self.assertAlmostEqual(r[6]['skills']['Imperial Decree']['ap'],120)
 def test_same_source_across_casters_keeps_first_and_expiry(self):
  b=self.b;b.apply(1,0,'Sunder','Crushing Barrage',0,3,6,True,mods={'def':-.58})
  b.t=3;self.assertFalse(b.apply(1,0,'Sunder','Crushing Barrage',0,6,6,True,mods={'def':-.8}))
  st=b.teams[1][0].statuses[0];self.assertEqual(st['caster'],3);self.assertEqual(st['expiry'],6)
  self.assertEqual(st['mods'],{'def':-.58})
  self.assertTrue(b.apply(1,0,'Sunder','Different Skill',0,6,6,True,mods={'def':-.1}))
 def test_duplicate_dot_and_barrage(self):
  b=self.b;b.t=7
  for i in [3,6]:b.teams[0][i].cd['Crushing Barrage']=0;b.cast(0,i,'Crushing Barrage',0)
  for v in b.teams[1]:
   self.assertEqual(len([s for s in v.statuses if s['tag']=='DOT']),1)
   self.assertEqual(len([s for s in v.statuses if s['tag']=='Sunder']),1)
  hp=b.teams[1][0].hp;b.ending()
  self.assertAlmostEqual(hp-b.teams[1][0].hp,827*1000/(1000+b.stat(b.teams[1][0],'sdef')))
 def test_stun_shared_limit_refresh_and_character_ap_only(self):
  b=self.b;u=b.teams[1][3]
  for turn in [1,2,3,4]:
   b.t=turn;b.add_count(1,3,0,0,1);b.add_count(1,3,0,1,1)
  self.assertEqual(u.stacks,0);self.assertEqual(u.stun_until,6)
  self.assertEqual(b.stat(u,'apr'),16)
 def test_summons_at_allied_start_only_and_no_double_summon(self):
  b=self.b;b.cast(0,5,'Summon Piercing Automaton',5);u=b.teams[0][5]
  self.assertEqual(u.metrics['automaton_attacks'],0)
  b.t=2;b.beginning(1);self.assertEqual(u.metrics['automaton_attacks'],0)
  b.t=3;b.beginning(0);self.assertEqual(u.metrics['automaton_attacks'],1)
  m=u.machines['Piercer'];self.assertAlmostEqual(m['atk'],u.base['atk']*1.1)
  self.assertEqual(m['cdb'],0);self.assertEqual(m['pen'],0);self.assertEqual(m['mhr'],1.12);self.assertEqual(m['stun'],1)
  u.ap=200;b.focus(0,5,0);self.assertEqual(b.choose_action(0,5)[0],'Summon Bombard Automaton')
 def test_machine_not_inherit_owner_stats_and_persists(self):
  b=self.b;b.cast(0,7,'Summon Piercing Automaton',7);u=b.teams[0][7];m=u.machines['Piercer']
  self.assertEqual(m['mhr'],1);self.assertEqual(m['chc'],0);self.assertAlmostEqual(m['atk'],u.base['atk']*1.2)
  u.hp=0;b.t=3;b.beginning(0);self.assertEqual(u.metrics['automaton_attacks'],1)
 def test_mona_only_low_hp_cleanses_oldest_two(self):
  b=self.b;u=b.teams[0][7];u.cd['Mona Lisa']=0
  self.assertEqual(b.choose_action(0,7)[0],'Summon Piercing Automaton')
  v=b.teams[0][0];v.hp=v.max_hp*.4
  b.apply(0,0,'Falter','War Cry',1,2,6,True,flat={'mhr':-.2})
  b.apply(0,0,'Sunder','Crushing Barrage',1,3,6,True,mods={'def':-.58})
  b.apply(0,0,'DOT','Crushing Barrage',1,3,6,True,power=827,scale=1)
  self.assertEqual(b.choose_action(0,7)[0],'Mona Lisa');before=v.hp;b.cast(0,7,'Mona Lisa',7)
  self.assertAlmostEqual(v.hp-before,8270);self.assertFalse(b.has(v,'Falter'));self.assertFalse(b.has(v,'Sunder'));self.assertTrue(b.has(v,'DOT'))
 def test_cooldown_first_global_turn_both_teams(self):
  b=self.b;self.assertEqual(b.teams[1][8].cd['Golden Arrow Shot'],1);b.ending();self.assertEqual(b.teams[1][8].cd['Golden Arrow Shot'],0)
 def test_counter_no_ap_no_extra_hits(self):
  b=self.b;u=b.teams[0][2];b.strike(0,2,0,counter=True)
  self.assertEqual(u.ap,0);events=[e for e in b.events if e['event']=='attack'];self.assertEqual(events[-1]['hits'],1)
 def test_robin_normal_priority_and_free_proc(self):
  b=self.b;u=b.teams[0][8];u.cd['Golden Arrow Shot']=0;u.cd['Man Under the Hood']=99
  self.assertEqual(b.choose_action(0,8)[0],'normal');mp=u.mp;b.cast(0,8,'Golden Arrow Shot',0,triggered=True)
  self.assertEqual(u.ap,0);self.assertEqual(mp-u.mp,u.skills['Golden Arrow Shot']['mp'])
 def test_duration_includes_apply_and_expires_before_next_start(self):
  b=self.b;b.apply(1,0,'Immobilized','Frozen Axe',0,0,3,True)
  for t in [1,2]:b.t=t;b.ending();self.assertTrue(b.has(b.teams[1][0],'Immobilized'))
  b.t=3;b.ending();self.assertFalse(b.has(b.teams[1][0],'Immobilized'))
 def test_main_death_stops_machine_sequence(self):
  b=self.b;u=b.teams[0][5];b.cast(0,5,'Summon Piercing Automaton',5);b.cast(0,5,'Summon Bombard Automaton',5)
  for i,v in enumerate(b.teams[1]):
   if i!=4:v.hp=0
  b.teams[1][4].hp=1;b.t=3;b.beginning(0)
  self.assertEqual(b.events[-1]['event'],'death');self.assertEqual(u.metrics['automaton_attacks'],1)
 def test_area_recipients_follow_slot_order(self):
  b=self.b;b.strike(0,0,1)
  damage=[e for e in b.events if e['event']=='damage' and e['team']==0 and e['source']=='normal']
  # Bluetooth's first hit resolves row recipients in slot order, retaining primary scale.
  first=damage[:3];self.assertEqual([e['target'] for e in first],[1,2,3])
  self.assertEqual([e['scale'] for e in first],[.8,1,.8])
 def test_full_match_resource_conservation_reproducibility(self):
  a=MixedBattle(self.data,seed=42);r=a.run();b=MixedBattle(self.data,seed=42);self.assertEqual(r,b.run())
  self.assertIn(r['winner'],[1,2]);a.check_resources()
  for team in a.teams:
   self.assertEqual(set(team[5].machines),{'Piercer','Devastator'});self.assertEqual(set(team[7].machines),{'Piercer'})
   self.assertGreater(team[7].metrics['Mona Lisa_casts'],0)
   for u in team:
    keys=[(s['tag'],s['source']) for s in u.statuses];self.assertEqual(len(keys),len(set(keys)))
