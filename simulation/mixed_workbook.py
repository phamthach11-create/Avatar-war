"""Import the selected mixed roster from cached workbook values and reviewed nodes.

Keeps source cells/text with every run. Only the explicit requested nodes are
handled; unsupported nodes fail rather than silently losing an effect.
"""
import copy,hashlib,re
from pathlib import Path
import openpyxl

STAT_NAMES={'HP':'hp','MP':'mp','Attack':'atk','Defense':'def','Skill Defense':'sdef','Multi-Hit Rate':'mhr','Penetration chance':'pen','Critical Hit Chance':'chc','Critical Damage Bonus':'cdb','AP Recovery':'apr','Stun Threshold':'threshold','Attack stun count':'stun','Skill Points':'sp','Accuracy':'acc','Evasion':'eva','Healing Amplification':'ha'}

def load_roster(path,scenario):
 w=openpyxl.load_workbook(path,data_only=True);f=openpyxl.load_workbook(path,data_only=False)
 result=[]
 for slot,choice in enumerate(scenario['roster']):
  sh=w[choice['sheet']];fs=f[choice['sheet']];stats={};chars={};catalog={};skills={};caps={}
  for row in sh:
   label=row[0].value
   if label in STAT_NAMES:
    key=STAT_NAMES[label];assert isinstance(row[1].value,(float,int)),(sh.title,label,'missing cached value')
    stats[key]=float(row[1].value);chars[key]=float(row[2].value or 0)
   for c in row:
    if isinstance(c.value,str):
     m=re.match(r'^(S[12](?:\.\d+)*)\.?\s*(.*)',c.value,re.S)
     if m:catalog[m[1]]={'cell':c.coordinate,'text':m[2]}
   if row[4].value and isinstance(row[1].value,(int,float,str)) and row[0].row>=32 and label and not str(label).startswith('Special'):
    name=re.sub(r'\s*[-—]\s*\d+\s*$','',str(label)).strip();m=re.search(r'[-—]\s*(\d+)\s*$',str(label));caps[name]=int(m[1]) if m else 5
    skills[name]={'ap':row[1].value if isinstance(row[1].value,(int,float)) else 0,'mp':float(row[2].value or 0),'cd':float(row[3].value) if isinstance(row[3].value,(int,float)) else 0,'duration':row[7].value or 0,'stat5':row[10].value,'description':row[4].value,'target':row[5].value,'area':row[6].value,'cell':row[0].coordinate,'formula':fs.cell(row[0].row,10).value,'parameters':{}}
    r=row[0].row+1
    while r<=sh.max_row and sh.cell(r,1).value is None:
     if sh.cell(r,9).value:
      skills[name]['parameters'][sh.cell(r,9).value]={'value':sh.cell(r,11).value,'formula':fs.cell(r,10).value}
     r+=1
  nodes=choice['nodes'];assert len(nodes)==6 and len(set(nodes))==6
  for n in nodes:
   assert n in catalog,(sh.title,n)
   if '.' in n:
    assert n[:2] in nodes
    bits=n.split('.')
    if len(bits)==3 and int(bits[-1])>1:assert '.'.join(bits[:-1]+[str(int(bits[-1])-1)]) in nodes
  mods={};eff={};extras={}
  def add(key,v):stats[key]+=v
  def mod(key,v):mods[key]=mods.get(key,0)+v
  def num(n,index=0):
   txt=catalog[n]['text']
   values=re.findall(r'(?<![\w.])[-+]?\d+(?:\.\d+)?',txt)
   return float(values[index]) if values else 0.
  typ=sh['B1'].value;name=sh['B2'].value
  for n in nodes:
   if '.' not in n:continue
   v=num(n)
   if typ=='Destroyer':
    if n in ['S1.1.1','S1.2.1']:add('apr',v)
    elif n=='S1.2.2':extras['secondary_penalty_delta']=v/100
    elif n=='S1.2.3':add('chc',v/100)
    elif n=='S1.2.4':add('mhr',v/100);add('chc',num(n,1)/100);add('cdb',num(n,2)/100)
    else:raise ValueError(n)
   elif typ=='Warrior':
    if n=='S1.1.1':add('apr',v)
    elif n=='S1.2.1':add('hp',v)
    elif n=='S1.2.2':mod('sdef',v/100)
    elif n=='S1.2.3':add('mp',v)
    elif n=='S1.2.4':extras['care_eff']=1+v/100
    else:raise ValueError(n)
   elif typ=='Soldier':
    if n in ['S1.1.1','S2.2.1']:mod('def',v/100)
    elif n=='S1.2.1':add('acc',v/100);add('chc',num(n,1)/100)
    elif n=='S1.2.2':extras['slayer_eff']=1+v/100
    elif n=='S1.2.3':add('def',v)
    elif n=='S1.2.4':extras['slayer_line']=True
    elif n=='S2.1.1':mod('atk',v/100)
    elif n=='S2.1.2':add('ha',v/100)
    elif n=='S2.1.3':add('threshold',v)
    elif n=='S2.1.4':extras['adjacent_aura']={'def':v/100,'atk':num(n,1)/100}
    else:raise ValueError(n)
   elif typ=='Devastator':
    if n in ['S1.1.1','S1.2.1','S2.2.1']:add('apr',v)
    elif n=='S1.2.2':add('hp',v)
    elif n=='S1.2.3':extras['battery_heal']=True
    elif n=='S1.2.4':extras['battery_eff']=1+v/100
    elif n=='S2.1.1':extras['decree_mp']=True
    elif n=='S2.1.2':mod('atk',v/100)
    elif n=='S2.1.3':skills['Imperial Decree']['ap']+=v
    elif n=='S2.1.4':extras['decree_chance_bonus']=v/100
    else:raise ValueError(n)
   elif typ=='Piercer':
    if n=='S1.1.1':pass # Unlock level 1 is included in assigned total SP, not an additional free level.
    elif n=='S1.2.1':
     for sk in skills.values():sk['mp']*=1-v/100
    elif n=='S1.2.2':extras['mona_cleanse_bonus']=v
    elif n=='S1.2.3':add('sp',v)
    elif n=='S1.3.1':add('mp',v)
    elif n=='S2.1.1':extras['machine_atk_eff']=1+v/100
    elif n=='S2.1.2':extras['machine_chc']=v/100
    elif n=='S2.1.3':add('hp',v)
    elif n=='S2.1.4':extras['piercing_stun']=v
    elif n=='S2.2.1':extras['machine_mhr']=1+v/100
    else:raise ValueError(n)
   elif typ=='Ranger':
    if n=='S1.1.1':mod('atk',v/100);add('mhr',num(n,1)/100)
    elif n=='S1.1.2':add('acc',v/100);mod('mhr',num(n,1)/100)
    elif n=='S1.1.3':extras['hood_ap']=v
    elif n=='S1.1.4':extras['golden_proc']=v/100
    elif n=='S1.2.1':extras['golden_mod']=v/100
    else:raise ValueError(n)
  chosen={};assert sum(choice['levels'].values())<=stats['sp'],(name,choice['levels'],stats['sp'])
  for sk,sl in choice['levels'].items():
   assert sk in skills and 0<sl<=caps[sk],(sk,sl,caps)
   spec=copy.deepcopy(skills[sk]);spec['level']=sl
   # Formula-specific nonlinear inheritance; all other selected primary stats scale linearly from SL5.
   spec['stat']=.5+.1*sl if sk.startswith('Summon ') else float(spec['stat5'])*sl/5
   chosen[sk]=spec
  result.append(dict(slot=slot,type=typ,name=name,stats=stats,character_ap=chars['apr'],mods=mods,eff=eff,extras=extras,skills=chosen,nodes=nodes,node_sources={n:catalog[n] for n in nodes},prefer_normal=choice.get('prefer_normal',False)))
 return {'roster':result,'workbook_sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),'scenario':scenario}
