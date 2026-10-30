"""Reviewed six-kit extension of TeamBattle; reuses its match loop and reports.

Status identity is (skill or kit-qualified node, tag), never caster identity.
This backend deliberately supports only the roster in mixed_mirror_automata.
"""
import copy,math,random
from collections import Counter
from .team_battle import TeamBattle

class MixedFighter:
 def __init__(self,p):
  self.p=copy.deepcopy(p);self.base=self.p['stats'];self.skills=self.p['skills'];self.extras=self.p['extras']
  self.max_hp=self.hp=self.base['hp'];self.max_mp=self.mp=self.base['mp'];self.ap=0.
  self.cd={k:v['cd'] for k,v in self.skills.items()};self.statuses=[];self.metrics=Counter();self.machines={}
  self.frozen_until=0;self.stun_until=0;self.stacks=0;self.stack_until=0;self.stack_last_turn=-1

class MixedBattle(TeamBattle):
 def __init__(self,d,first=0,seed=42):
  self.d=d;self.first=first;self.seed=seed;self.builds=(1,2);self.rng=random.Random(seed)
  self.main=4;self.size=9;self.elimination=False;self.t=0;self.events=[];self.turns=[];self.detailed=True;self.sequence=0
  self.teams=[[MixedFighter(p) for p in d['roster']] for _ in range(2)];self.positions=[0,0];self.f=[self.teams[0][0],self.teams[1][0]]
  self.initial=self.snapshot()
  # A continuous passive has no cast; its status contributions exist while its owner lives.
  for side,team in enumerate(self.teams):
   for i,u in enumerate(team):
    if 'adjacent_aura' in u.extras:
     for j,_ in self.area(i,'Cross'):
      for stat,v in u.extras['adjacent_aura'].items():
       self.apply(side,j,'Fortify' if stat=='def' else 'Rage','Soldier:S2.1.4',side,i,100000,mods={stat:v},continuous=True)

 def snapshot(self):
  return [[dict(slot=i+1,name=u.p['name'],hp=u.hp,mp=u.mp,ap=u.ap,cooldowns=u.cd.copy(),statuses=copy.deepcopy(u.statuses),machines=copy.deepcopy(u.machines),metrics=dict(u.metrics)) for i,u in enumerate(team)] for team in self.teams]

 def emit(self,event,**kw):
  self.sequence+=1;self.events.append(dict(turn=self.t,sequence=self.sequence,event=event,**kw))

 def active_statuses(self,u):return [s for s in u.statuses if s['expiry']>=self.t and (not s.get('continuous') or self.teams[s['caster_side']][s['caster']].hp>0)]
 def has(self,u,tag,source=None):return any(s['tag']==tag and (source is None or s['source']==source) for s in self.active_statuses(u))
 def stat(self,u,key):
  st=self.active_statuses(u);base=u.base[key]+sum(s.get('flat',{}).get(key,0) for s in st)
  if key=='apr' and self.active(u.stun_until):base-=u.p['character_ap']
  val=base*(1+u.p['mods'].get(key,0)+sum(s.get('mods',{}).get(key,0) for s in st))*(1+u.p['eff'].get(key,0))
  return max(1 if key in ['mhr','threshold'] else 0,val)

 def apply(self,side,pos,tag,source,cs,ci,duration,negative=False,**data):
  u=self.teams[side][pos]
  if u.hp<=0:return False
  if negative and (self.has(u,'Immunity') or self.has(u,'Invincible')):return False
  if self.has(u,tag,source):
   self.emit('status_duplicate_ignored',team=side,slot=pos+1,tag=tag,source=source,caster_side=cs,caster=ci+1);return False
  self.sequence+=1
  u.statuses.append(dict(tag=tag,source=source,caster_side=cs,caster=ci,applied=self.t,expiry=self.t+duration-1,order=self.sequence,negative=negative,**data))
  self.sync_status(u);self.emit('status_applied',team=side,slot=pos+1,tag=tag,source=source,expires=self.t+duration-1,parameters=data);return True

 def sync_status(self,u):
  u.frozen_until=max([s['expiry'] for s in u.statuses if s['tag']=='Immobilized'] or [0])
  u.stun_until=max([s['expiry'] for s in u.statuses if s['tag']=='Stun'] or [0])
  counts=[s for s in u.statuses if s['tag']=='Stun Count']
  if not counts:u.stacks=0;u.stack_until=0

 def add_count(self,side,pos,cs,ci,amount):
  u=self.teams[side][pos]
  if not amount or u.hp<=0 or self.active(u.stun_until) or u.stack_last_turn==self.t or self.has(u,'Immunity') or self.has(u,'Invincible'):return
  u.stacks+=amount;u.stack_last_turn=self.t;u.stack_until=self.t+2
  u.statuses=[s for s in u.statuses if s['tag']!='Stun Count']
  self.apply(side,pos,'Stun Count','Stun Count',cs,ci,3,True)
  self.teams[cs][ci].metrics['stun_count_applied']+=1
  self.emit('stun_count',team=side,slot=pos+1,count=u.stacks)
  if u.stacks>=self.stat(u,'threshold'):
   u.statuses=[s for s in u.statuses if s['tag']!='Stun Count'];u.stacks=0;u.stack_until=0
   self.apply(side,pos,'Stun','Stun',cs,ci,3,True);self.teams[cs][ci].metrics['stuns']+=1

 def area(self,target,kind,secondary=.5):
  r,c=divmod(target,3)
  if kind=='Single':return [(target,1.)]
  if kind=='Row':return [(target,1.)]+[(r*3+j,1.) for j in range(3) if j!=c]
  if kind=='Adjacent Row':return [(target,1.)]+[(r*3+j,secondary) for j in [c-1,c+1] if 0<=j<3]
  if kind=='Line Adjacent':return [(target,1.)]+([(target+3,secondary)] if r<2 else [])
  if kind=='Full Line':return [(target,1.)]+[(j*3+c,.5 if j==r+1 else .25) for j in range(r+1,3)]
  if kind=='Cross':return [(target,1.)]+[(rr*3+cc,secondary) for rr,cc in [(r-1,c),(r+1,c),(r,c-1),(r,c+1)] if 0<=rr<3 and 0<=cc<3]
  raise ValueError(kind)

 def weapon_area(self,u,target,machine=None):
  typ=machine['type'] if machine else u.p['type']
  kind={'Warrior':'Single','Soldier':'Line Adjacent','Destroyer':'Adjacent Row','Piercer':'Full Line','Ranger':'Single','Caster':'Single','Devastator':'Cross'}[typ]
  penalty=.5+(u.extras.get('secondary_penalty_delta',0) if not machine else 0)
  return self.area(target,kind,1-penalty)

 def legal_targets(self,enemy,kind):
  pool=super().legal_targets(enemy,'Any' if kind=='Rows12' else kind)
  return [j for j in pool if not self.has(self.teams[enemy][j],'Invisible') and (kind!='Rows12' or j<6)]

 def ready_at(self,u,name):return name in u.skills and u.cd[name]<=0 and u.mp+1e-7>=u.skills[name]['mp']
 def disabled(self,u):return u.hp<=0 or self.active(u.stun_until) or self.active(u.frozen_until)

 def hurt(self,side,actor,target,raw,skill,source,pen=False,scale=1,critical=False,blocked=False):
  u=self.teams[side][actor];v=self.teams[1-side][target]
  if v.hp<=0 or not self.alive():return 0
  defense=self.stat(v,'sdef' if skill else 'def');final=raw*(1 if pen else 1000/(1000+defense))*scale
  if blocked or self.has(v,'Invincible'):final=0
  actual=min(v.hp,final);v.hp-=actual;u.metrics['effective_damage']+=actual;u.metrics[source+'_damage']+=actual
  u.metrics['raw_damage']+=raw*scale;u.metrics['final_damage']+=final
  if target==self.main:u.metrics['main_damage']+=actual
  self.emit('damage',team=side,slot=actor+1,target_team=1-side,target=target+1,source=source,raw=raw,defense=defense,scale=scale,critical=critical,penetrated=pen,blocked=blocked,damage=actual,hp=v.hp)
  if v.hp<=0:self.emit('death',team=1-side,slot=target+1,main=target==self.main,source=source)
  return actual

 def heal(self,side,actor,target,amount,source):
  v=self.teams[side][target]
  if v.hp<=0:return
  value=min(v.max_hp-v.hp,amount*(1+self.stat(v,'ha')));v.hp+=value
  self.teams[side][actor].metrics['healing']+=value;self.teams[side][actor].metrics[source+'_healing']+=value
  self.emit('heal',team=side,slot=actor+1,target=target+1,source=source,heal=value,hp=v.hp)

 def cleanse(self,side,actor,target,count,source):
  u=self.teams[side][target];bad=sorted([s for s in self.active_statuses(u) if s['negative']],key=lambda s:s['order'])[:int(count)]
  for s in bad:u.statuses.remove(s)
  self.sync_status(u);self.emit('cleanse',team=side,slot=actor+1,target=target+1,source=source,removed=[s['tag'] for s in bad])

 def strike(self,side,actor,target,machine=None,counter=False,coordinated=False):
  u=self.teams[side][actor];typ=machine['type'] if machine else u.p['type'];source='counterattack' if counter else 'coordinated_attack' if coordinated else ('automaton_'+typ if machine else 'normal')
  if not machine and self.disabled(u):return
  if not machine and not counter:
   u.ap-=100;u.metrics['ap_spent']+=100;u.metrics['normal_attacks' if not coordinated else 'coordinated_attacks']+=1
  mhr=machine['mhr'] if machine else self.stat(u,'mhr');hits=1 if counter else math.floor(mhr)+(self.rng.random()<mhr%1)
  cells=[(target,1.)] if counter and typ in ['Warrior','Soldier','Destroyer'] else self.weapon_area(u,target,machine)
  if machine:u.metrics['automaton_attacks']+=1
  self.emit('attack',team=side,slot=actor+1,target=target+1,source=source,hits=hits,ap=u.ap)
  for hit in range(hits):
   if not self.alive() or (not machine and self.disabled(u)):break
   for j,scale in sorted(cells):
    if not self.alive() or (not machine and self.disabled(u)):break
    v=self.teams[1-side][j]
    if v.hp<=0 or not self.alive():continue
    acc=1 if machine else self.stat(u,'acc')
    if self.rng.random()>=max(0,min(1,acc-self.stat(v,'eva'))):self.emit('miss',team=side,slot=actor+1,target=j+1,source=source);continue
    crit=self.rng.random()<(machine['chc'] if machine else self.stat(u,'chc'));pen=self.rng.random()<(machine['pen'] if machine else self.stat(u,'pen'))
    ph=v.skills.get('Phalanx');chance=ph['stat'] if ph else 0
    ranged=typ in ['Piercer','Ranger','Devastator','Caster'];block=bool(chance and ranged and self.rng.random()<chance)
    raw=(machine['atk'] if machine else self.stat(u,'atk'))*(1+(machine['cdb'] if machine else self.stat(u,'cdb')) if crit else 1)
    self.hurt(side,actor,j,raw,False,source,pen,scale,crit,block)
    if not self.alive():return
    self.add_count(1-side,j,side,actor,machine['stun'] if machine else self.stat(u,'stun'))
    if block:v.metrics['blocks']+=1
    # A machine is an independent ranged attacker; neither owner proc nor decree is inherited.
    if not machine and u.extras.get('golden_proc') and v.hp>0 and self.rng.random()<u.extras['golden_proc'] and self.ready_at(u,'Golden Arrow Shot'):
     self.cast(side,actor,'Golden Arrow Shot',j,triggered=True)
    if not counter and chance and not ranged and v.hp>0 and not self.disabled(v) and self.rng.random()<chance:
     v.metrics['counterattacks']+=1;self.strike(1-side,j,actor,counter=True)
  if not machine and not counter and not coordinated and self.alive():
   for status in list(self.active_statuses(u)):
    if status['tag']=='Imperial Decree':
     ci=status['caster'];co=self.teams[side][ci]
     if not self.disabled(co) and self.teams[1-side][target].hp>0 and self.rng.random()<status['chance']:
      self.strike(side,ci,target,coordinated=True)

 def cast(self,side,pos,name,target,triggered=False):
  u=self.teams[side][pos];assert self.ready_at(u,name),(name,u.mp,u.cd)
  sk=u.skills[name];u.mp-=sk['mp'];u.cd[name]=sk['cd'];u.metrics['mp_spent']+=sk['mp'];u.metrics[name+'_casts']+=1
  ap=0 if triggered else sk['ap'];u.ap-=ap;u.metrics['ap_spent']+=ap
  self.emit('cast',team=side,slot=pos+1,skill=name,target=target+1,mp_cost=sk['mp'],ap_cost=ap,mp=u.mp,ap=u.ap,triggered=triggered)
  dur=sk['duration'];sl=sk['level'];enemy=1-side
  def app(j,tag,negative=True,**data):return self.apply(enemy if negative else side,j,tag,name,side,pos,dur,negative,**data)
  if name.startswith('Summon '):
   typ='Piercer' if 'Piercing' in name else 'Devastator'
   assert typ not in u.machines
   u.machines[typ]=dict(type=typ,atk=self.stat_base(u,'atk')*sk['stat']*u.extras.get('machine_atk_eff',1),mhr=u.extras.get('machine_mhr',1),chc=u.extras.get('machine_chc',0),cdb=0,pen=0,stun=1 if typ=='Devastator' else u.extras.get('piercing_stun',0),summoned=self.t)
   self.emit('summon',team=side,slot=pos+1,machine=copy.deepcopy(u.machines[typ]));return
  if name=='Man Under the Hood':
   if not self.has(u,'Immunity'):
    app(pos,'Invisible',False);app(pos,'Precision',False,flat={'chc':sk['stat']})
    recovered=u.extras.get('hood_ap',0);u.ap+=recovered;u.metrics['ap_restored']+=recovered
   return
  if name in ['Mona Lisa','Holy Guard','Maiden’s Care','Grand Battery','Imperial Decree']:
   targets=list(range(9)) if name=='Mona Lisa' else [j for j,v in enumerate(self.teams[side]) if v.p['type']=='Devastator'] if name=='Grand Battery' else [target]
   for j in targets:
    v=self.teams[side][j]
    if v.hp<=0 or self.has(v,'Immunity'):continue
    if name=='Mona Lisa':self.heal(side,pos,j,sk['stat'],name);self.cleanse(side,pos,j,1+u.extras.get('mona_cleanse_bonus',0),name)
    elif name=='Holy Guard':self.heal(side,pos,j,sk['stat'],name);app(j,'Immunity',False)
    elif name=='Maiden’s Care':
     factor=u.extras.get('care_eff',1);self.heal(side,pos,j,sk['stat']*factor,name)
     rate=self.param(sk,'Resistance: Base SDEF Scaling Rate',sl)*factor
     app(j,'Resistance',False,flat={'sdef':self.stat_base(u,'sdef')*rate})
    elif name=='Grand Battery':
     factor=u.extras.get('battery_eff',1)
     app(j,'Rage',False,mods={'atk':sk['stat']*factor});app(j,'Onslaught',False,mods={'mhr':self.param(sk,'Onslaught: Multi-Hit Rate Modifier Bonus',sl)*factor})
     if u.extras.get('battery_heal'):self.heal(side,pos,j,self.param(sk,'Heal (Upgrade)',sl)*factor,name)
    elif name=='Imperial Decree':
     app(j,'Imperial Decree',False,chance=min(1,sk['stat']+u.extras.get('decree_chance_bonus',0)))
     if u.extras.get('decree_mp'):
      gain=min(v.max_mp-v.mp,self.param(sk,'MP Recovery (Upgrade)',sl));v.mp+=gain;v.metrics['mp_restored']+=gain;self.emit('mp_restore',team=side,slot=pos+1,target=j+1,mp=gain)
   return
  if name=='Crushing Barrage':cells=[(j,1) for j in range(9)]
  elif name=='War Cry':cells=self.area(target,'Cross')
  elif name=='Frozen Axe':cells=self.area(target,'Row')
  elif name=='Holy Blade' or name=='God-King Slayer' and u.extras.get('slayer_line'):cells=self.area(target,'Line Adjacent')
  else:cells=[(target,1)]
  for j,scale in sorted(cells):
   v=self.teams[enemy][j]
   if v.hp<=0 or not self.alive() or self.has(v,'Immunity'):continue
   if name=='Crushing Barrage':
    app(j,'Sunder',mods={'def':sk['stat']});app(j,'DOT',power=self.param(sk,'DOT SATK',sl),scale=1,double=False)
   elif name=='War Cry':
    app(j,'DOT',power=self.param(sk,'DOT SATK',sl),scale=scale,double=True);app(j,'Falter',flat={'mhr':sk['stat']})
   elif name=='Frozen Axe':
    self.hurt(side,pos,j,sk['stat'],True,name,scale=scale)
    if not self.alive():return
    app(j,'DOT',power=self.param(sk,'DOT SATK',sl),scale=scale,double=False);app(j,'Immobilized')
   elif name=='Holy Blade':
    self.hurt(side,pos,j,sk['stat'],True,name,scale=scale)
    if self.alive():self.add_count(enemy,j,side,pos,self.param(sk,'Stun Count',sl))
   elif name=='God-King Slayer':
    crit=self.rng.random()<self.param(sk,'Base CHC',sl)
    raw=sk['stat']*(u.extras.get('slayer_eff',1)+(.5 if j==self.main else 0))*(1+self.stat(u,'cdb') if crit else 1)
    self.hurt(side,pos,j,raw,True,name,scale=scale,critical=crit)
   elif name=='Golden Arrow Shot':self.hurt(side,pos,j,sk['stat']*(1+u.extras.get('golden_mod',0)),True,name)
   elif name=='Deadly Strike':self.hurt(side,pos,j,sk['stat'],True,name)
   else:raise ValueError('Unsupported skill '+name)

 def stat_base(self,u,key):return u.base[key]+sum(s.get('flat',{}).get(key,0) for s in self.active_statuses(u))
 def param(self,sk,name,sl):
  p=sk['parameters'][name];v=p['value'] if p['value'] is not None else p['formula']
  if isinstance(v,(int,float)):
   return float(v)*(sl/5 if isinstance(p['formula'],str) and 'sl' in p['formula'].lower() else 1)
  raise ValueError((name,p))

 def beginning(self,side):
  # Slot order resolves selected start-of-turn skills and existing machines.
  for pos,u in enumerate(self.teams[side]):
   if not self.alive():return []
   for name,sk in sorted(u.skills.items(),key=lambda kv:int(kv[1]['cell'][1:])):
    if not self.alive():return []
    if name.startswith('Summon '):
     typ='Piercer' if 'Piercing' in name else 'Devastator'
     if typ in u.machines:
      m=u.machines[typ];pool=self.legal_targets(1-side,'Front' if typ=='Piercer' else 'Any')
      if pool:self.strike(side,pos,self.rng.choice(pool),machine=m)
    elif u.hp>0 and self.ready_at(u,name) and name in ['Maiden’s Care','Grand Battery']:
     self.cast(side,pos,name,self.main if name=='Maiden’s Care' else pos)
   if u.hp>0:u.metrics['team_turns']+=1
  if not self.alive():return []
  eligible=[]
  for i,u in enumerate(self.teams[side]):
   if u.hp<=0:continue
   gain=self.stat(u,'apr');u.ap+=gain;u.metrics['ap_recovered']+=gain
   if self.active(u.stun_until):u.metrics['stunned_team_turns']+=1
   if self.active(u.frozen_until):u.metrics['frozen_team_turns']+=1
   if not self.disabled(u) and u.ap>=100:eligible.append(i)
  self.rng.shuffle(eligible);eligible.sort(key=lambda j:self.teams[side][j].ap,reverse=True)
  cap=2 if self.t<=2 else 4 if self.t<=4 else 5
  for i in eligible[:cap]:self.teams[side][i].metrics['initial_slots']+=1
  return eligible[:cap]

 def ending(self):
  side=self.first if self.t%2 else 1-self.first
  for enemy in [side,1-side]:
   for j,u in enumerate(self.teams[enemy]):
    for st in sorted(list(self.active_statuses(u)),key=lambda z:z['order']):
     if u.hp<=0 or not self.alive():break
     if st['tag']=='DOT':
      raw=st['power']*(2 if st.get('double') and self.stat(u,'mhr')<=1+1e-9 else 1)
      self.hurt(st['caster_side'],st['caster'],j,raw,True,'DOT:'+st['source'],scale=st['scale'])
    if not self.alive():break
  if not self.alive():return
  for team in self.teams:
   for u in team:
    expired=[s for s in u.statuses if s['expiry']<=self.t]
    for st in expired:self.emit('status_expired',tag=st['tag'],source=st['source'])
    u.statuses=[s for s in u.statuses if s['expiry']>self.t];self.sync_status(u)
    if u.hp>0:u.cd={k:max(0,v-1) for k,v in u.cd.items()}
  self.turns.append(dict(turn=self.t,team=side,state=self.snapshot()))

 def choose_target(self,enemy,pool):
  if not pool:return None
  return super().choose_target(enemy,pool)

 def choose_action(self,side,pos):
  u=self.teams[side][pos];enemy=1-side;kind='Any' if u.p['type'] in ['Ranger','Devastator'] else 'Front';pool=self.legal_targets(enemy,kind)
  target=self.choose_target(enemy,pool)
  if target is None:return 'wait',0
  # Heal only when someone is below the explicit scenario threshold, not on cooldown alone.
  if self.ready_at(u,'Mona Lisa'):
   need=[v for v in self.teams[side] if v.hp>0 and not self.has(v,'Immunity') and v.hp/v.max_hp<self.d['scenario']['mona_hp_threshold']]
   if need:return 'Mona Lisa',pos
  for name in ['Summon Piercing Automaton','Summon Bombard Automaton']:
   typ='Piercer' if 'Piercing' in name else 'Devastator'
   if self.ready_at(u,name) and typ not in u.machines:return name,pos
  if self.ready_at(u,'Holy Guard'):
   allies=[j for j,v in enumerate(self.teams[side]) if v.hp>0 and v.hp/v.max_hp<.5 and not self.has(v,'Immunity')]
   if allies:return 'Holy Guard',self.main if self.main in allies else min(allies,key=lambda j:self.teams[side][j].hp/self.teams[side][j].max_hp)
  if self.ready_at(u,'Man Under the Hood') and not self.has(u,'Invisible'):return 'Man Under the Hood',pos
  if u.p['prefer_normal']:return 'normal',target
  if self.ready_at(u,'Imperial Decree'):
   pool2=[j for j,v in enumerate(self.teams[side]) if v.hp>0 and j!=pos and v.p['type']=='Devastator' and not self.has(v,'Imperial Decree') and not self.has(v,'Immunity')]
   if pool2:return 'Imperial Decree',pool2[0]
  def expected(j,skill=False,raw=None):
   v=self.teams[enemy][j]
   if skill and self.has(v,'Immunity'):return 0
   if raw is None:raw=self.stat(u,'atk')*self.stat(u,'mhr')*(1+self.stat(u,'chc')*self.stat(u,'cdb'))*max(0,min(1,self.stat(u,'acc')-self.stat(v,'eva')))
   return raw*1000/(1000+self.stat(v,'sdef' if skill else 'def'))
  normal=sum(expected(j)*scale for j,scale in self.weapon_area(u,target) if self.teams[enemy][j].hp>0)
  options=[(normal,'normal',target)]
  for name in ['Golden Arrow Shot','Deadly Strike','Holy Blade','God-King Slayer','Frozen Axe','Crushing Barrage','War Cry']:
   if not self.ready_at(u,name):continue
   if name=='Deadly Strike' and u.hp>=u.max_hp*.5:continue
   sk=u.skills[name];allowed=self.legal_targets(enemy,'Rows12' if name in ['God-King Slayer','War Cry'] else 'Any' if name in ['Golden Arrow Shot','Crushing Barrage'] else 'Front')
   for j in allowed:
    if name=='Crushing Barrage':
     fresh=[k for k,v in enumerate(self.teams[enemy]) if v.hp>0 and not self.has(v,'Immunity') and not self.has(v,'DOT',name)]
     score=sum(expected(k,True,self.param(sk,'DOT SATK',sk['level']))*sk['duration'] for k in fresh)
     if len(fresh)<3:continue
    elif name=='War Cry':
     cells=[(k,scale) for k,scale in self.area(j,'Cross') if self.teams[enemy][k].hp>0 and not self.has(self.teams[enemy][k],'DOT',name)]
     score=sum(expected(k,True,self.param(sk,'DOT SATK',sk['level']))*scale*sk['duration'] for k,scale in cells)
    elif name=='Frozen Axe':
     cells=[k for k,_ in self.area(j,'Row') if self.teams[enemy][k].hp>0]
     if any(self.has(self.teams[enemy][k],'Immobilized') or self.has(self.teams[enemy][k],'DOT',name) for k in cells):continue
     score=sum(expected(k,True,sk['stat']+self.param(sk,'DOT SATK',sk['level'])*sk['duration']) for k in cells)
     # Control priority is explicit, not pretending damage-only optimization is exact.
     if any(not self.has(self.teams[enemy][k],'Immunity') for k in cells):score+=normal
    else:
     raw=sk['stat'];cells=self.area(j,'Line Adjacent') if name=='Holy Blade' or name=='God-King Slayer' and u.extras.get('slayer_line') else [(j,1)]
     score=0
     for k,scale in cells:
      if self.teams[enemy][k].hp<=0:continue
      value=raw
      if name=='God-King Slayer':value*= (u.extras.get('slayer_eff',1)+(.5 if k==self.main else 0))*(1+.65*self.stat(u,'cdb'))
      if name=='Golden Arrow Shot':value*=1+u.extras.get('golden_mod',0)
      score+=expected(k,True,value)*scale
    if j==self.main:score*=1.2
    options.append((score,name,j))
  return max(options,key=lambda z:z[0])[1:]

 def perform_action(self,side,act,target):
  pos=self.positions[side];u=self.teams[side][pos]
  if act=='wait':return
  if act=='normal':self.strike(side,pos,target)
  else:
   self.cast(side,pos,act,target)
   if act=='Man Under the Hood' and not self.disabled(u) and self.alive():
    # The skill grants one additional action slot immediately; no AP>=100 check.
    u.metrics['extra_slots']+=1;act,target=self.choose_action(side,pos)
    if act!='Man Under the Hood':self.focus(side,pos,target);self.perform_action(side,act,target)

 def check_resources(self):
  for side,team in enumerate(self.teams):
   for u in team:
    assert -1e-7<=u.mp<=u.max_mp+1e-7 and -1e-7<=u.hp<=u.max_hp+1e-7
    assert abs(u.max_mp-u.mp-u.metrics['mp_spent']+u.metrics['mp_restored'])<1e-5
    assert abs(u.ap-u.metrics['ap_recovered']+u.metrics['ap_spent']-u.metrics['ap_restored'])<1e-5
   lost=sum(u.max_hp-u.hp for u in team)
   assert abs(lost-self.metrics(1-side)['effective_damage']+self.metrics(side)['healing'])<1e-4
