"""Deterministic extraction, change routing, and guarded runtime publication.

Descriptions/formulas are design input, NEVER executable Python/GDScript.
An unhandled change stops publication. Existing engine/builds are reused.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[2]
WORKBOOK = 'data/excel/Thiết kế game.xlsx'
LOCK = 'design/sync/accepted.json'
FIELDS = {'HP':'max_hp','MP':'max_mp','Attack':'attack','Defense':'defense',
          'Skill Defense':'skill_defense','Multi-Hit Rate':'multi_hit_rate',
          'Penetration chance':'penetration_chance','Critical Hit Chance':'critical_chance',
          'Critical Damage Bonus':'critical_damage_bonus','AP Recovery':'ap_recovery',
          'Stun Threshold':'stun_threshold','Attack stun count':'attack_stun_count',
          'Skill Points':'skill_points','Accuracy':'accuracy','Evasion':'evasion',
          'Healing Amplification':'healing_amp'}

def digest_bytes(data):
    return hashlib.sha256(data).hexdigest()

def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode('utf-8')

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_bytes(encoded(value))
    temp.replace(path)

def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)

def extract(path):
    """Keep source expressions AND cached values; openpyxl does not recalculate."""
    formulas = load_workbook(path, data_only=False)
    values = load_workbook(path, data_only=True)
    sheets = {}
    for sheet in formulas:
        cells = {}
        for row in sheet:
            for cell in row:
                cached = values[sheet.title][cell.coordinate].value
                if cell.value is not None or cached is not None:
                    raw = cell.value
                    if not isinstance(raw, (str, int, float, bool, type(None))): raw = str(raw)
                    if not isinstance(cached, (str, int, float, bool, type(None))): cached = str(cached)
                    cells[cell.coordinate] = {'source': raw, 'value': cached}
        sheets[sheet.title] = cells
    formulas.close(); values.close()
    return {'schema_version':1, 'workbook_sha256':digest_bytes(Path(path).read_bytes()), 'sheets':sheets}

def engine_hashes(root):
    return {p.relative_to(root).as_posix():digest_bytes(p.read_text(encoding='utf-8').replace('\r\n','\n').encode('utf-8'))
            for p in sorted((root/'src/combat').glob('*.gd'))}

def differences(old, new):
    changes = []
    for sheet in sorted(set(old['sheets']) | set(new['sheets'])):
        a = old['sheets'].get(sheet, {}); b = new['sheets'].get(sheet, {})
        for cell in sorted(set(a) | set(b)):
            if a.get(cell) != b.get(cell):
                changes.append({'sheet':sheet, 'cell':cell, 'before':a.get(cell), 'after':b.get(cell)})
    return changes

def classify(change, baseline):
    sheet, cell = change['sheet'], change['cell']
    old, new = change['before'], change['after']
    if not old or not new: return 'review_structure'
    # Cache-only updates are data changes, but formula source edits always need review.
    if old['source'] == new['source']:
        if not number(new['value']): return 'review_cache'
        row = int(''.join(c for c in cell if c.isdigit()))
        if sheet.endswith(' class') and row < 30: return 'data_cache'
        if sheet.endswith(' class') and cell[0] in ('B','C','D') and row >= 32:
            return 'data_skill_cost' if baseline['sheets'][sheet].get('E'+str(row)) else 'review_effect_cache'
        return 'review_effect_cache'
    if not number(old['source']) or not number(new['source']):
        return 'review_formula' if str(new['source']).startswith('=') else 'review_rule_or_text'
    if sheet.endswith(' class'):
        col = ''.join(c for c in cell if c.isalpha()); row = int(''.join(c for c in cell if c.isdigit()))
        label = baseline['sheets'][sheet].get('A'+str(row), {}).get('source')
        if col in ('B','C') and label in FIELDS: return 'data_stat'
        # Skill costs may be numeric; duration, targeting and effect values remain mechanic review.
        if col in ('B','C','D') and row >= 32 and baseline['sheets'][sheet].get('E'+str(row)):
            return 'data_skill_cost'
    if sheet == 'Item' and cell.startswith('F'): return 'data_item'
    return 'review_unbound_numeric'

def required_value(cells, cell):
    value = cells.get(cell, {}).get('value')
    if not number(value):
        raise ValueError(f'{cell}: missing/non-finite cached number; recalculate and save Excel first')
    return value

def build_scenario(snapshot, template):
    """Refresh existing roster; do not invent builds or new effect handlers."""
    result = copy.deepcopy(template)
    for unit in result['roster']:
        cells = snapshot['sheets'][unit['type']+' class']
        for row in range(9,28):
            label = str(cells.get('A'+str(row),{}).get('value','')).strip()
            if label in FIELDS:
                unit[FIELDS[label]] = required_value(cells, 'B'+str(row))
        unit['character_ap_recovery'] = required_value(cells, 'C21')
        # Explicit user/build choices are preserved, separate from Excel base stats.
        if unit['type']=='Soldier': unit.update(accuracy=1, evasion=0)
        if unit['type']=='Piercer' and 'S1' in unit['nodes']: unit['skill_points'] += 7
        if unit.get('max_hp',0) <= 0 or any(unit.get(k,0) < 0 for k in FIELDS.values()):
            raise ValueError(f'{unit["type"]}: invalid negative stat or nonpositive HP')
        if sum(unit.get('levels',{}).values()) > unit.get('skill_points',0):
            raise ValueError(f'{unit["type"]}: existing build exceeds new skill point budget; choose build explicitly')
        for name, skill in unit['skills'].items():
            row = str(skill['sheet_row'])
            expected = str(cells.get('A'+row,{}).get('value',''))
            if not expected.startswith(name): raise ValueError(f'Skill identity moved: {name}, row {row}')
            for col, key in [('B','ap'),('C','mp'),('D','cd')]:
                raw = cells.get(col+row,{}).get('value')
                if number(raw): skill[key] = raw
                elif key != 'ap': raise ValueError(f'{name} {key}: nonnumeric cost/cooldown')
            if any(skill[k] < 0 for k in ('ap','mp','cd')) or skill['cd'] != int(skill['cd']):
                raise ValueError(f'{name}: costs must be nonnegative and cooldown integral')
            # Keep other effect fields frozen until their handlers are reviewed.
    result['source_sha256'] = snapshot['workbook_sha256']
    return result

def run(root, workbook, publish=False, recalculated=False):
    accepted = read(root/LOCK)
    baseline = read(root/accepted['snapshot'])
    current = extract(workbook)
    changes = differences(baseline, current)
    for change in changes: change['route'] = classify(change, baseline)
    blockers = [c for c in changes if c['route'].startswith('review_')]
    errors = []
    if engine_hashes(root) != accepted['engine_files']:
        errors.append('Combat engine changed; update implementation receipt after verification.')
    if any(c['before'] and c['after'] and c['before']['source'] != c['after']['source'] for c in changes) and not recalculated:
        errors.append('Source values changed: save a recalculated workbook, then use --recalculated to attest the saved Excel cache.')
    template = read(root/'design/scenarios/requested_9v9.template.json')
    scenario = None
    try: scenario = build_scenario(current, template)
    except (KeyError, ValueError) as exc: errors.append(str(exc))
    report = {'schema_version':1,'state':'blocked' if blockers or errors else 'ready',
              'source_sha256':current['workbook_sha256'], 'accepted_sha256':accepted['workbook_sha256'],
              'changes':changes,'blocker_count':len(blockers),'errors':errors,
              'engine_files':engine_hashes(root),'source':'repository workbook'}
    save(root/'design/sync/pending/report.json', report)
    save(root/'design/sync/pending/snapshot.json', current)
    # Partition all design input, even unsupported/new sheets, to keep it discoverable.
    for name, cells in current['sheets'].items():
        safe = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name).strip('_')
        group = 'classes' if name.endswith(' class') else 'rules' if name in ('Combat Mechanics','Terminology','status') else 'tables'
        save(root/f'design/sync/pending/{group}/{safe}.json', cells)
    if scenario: save(root/'design/sync/pending/scenarios/requested_9v9.json', scenario)
    if publish and report['state']=='ready':
        # Immutable content-addressed bundle, atomic pointer switched last.
        bundle = {'schema_version':1,'source_sha256':current['workbook_sha256'],
                  'engine_files':report['engine_files'],'scenarios':{'requested_9v9':scenario}}
        revision = digest_bytes(encoded(bundle))
        relative = f'data/runtime/bundles/{revision}.json'
        save(root/relative, bundle)
        save(root/'data/runtime/active.json', {'schema_version':1,'source':WORKBOOK,
             'source_sha256':current['workbook_sha256'],'bundle':relative,'bundle_sha256':revision})
        # Accept only safely-bound numerical/cache changes. Semantic changes need code+receipt work.
        snapshot_path = f'design/sync/snapshots/{current["workbook_sha256"]}.json'
        save(root/snapshot_path, current)
        accepted.update(workbook_sha256=current['workbook_sha256'], snapshot=snapshot_path)
        save(root/LOCK, accepted)
    return report

def verify_active(root):
    active = read(root/'data/runtime/active.json')
    if digest_bytes((root/active['source']).read_bytes()) != active['source_sha256']:
        raise ValueError('Excel changed: run design_sync; current runtime is stale.')
    raw = (root/active['bundle']).read_bytes()
    if digest_bytes(raw) != active['bundle_sha256']: raise ValueError('Runtime bundle was modified.')
    bundle = json.loads(raw)
    if bundle['engine_files'] != engine_hashes(root): raise ValueError('Engine revision differs from runtime bundle.')
    return active

def accept_review(root, receipt_path):
    """Engineer checkpoint after implementing semantic changes, never a force flag."""
    receipt = read(receipt_path)
    snapshot = extract(root/WORKBOOK)
    accepted = read(root/LOCK)
    changes = differences(read(root/accepted['snapshot']), snapshot)
    if receipt.get('source_sha256') != snapshot['workbook_sha256']:
        raise ValueError('Receipt does not match this exact workbook.')
    if receipt.get('reviewed_change_sha256') != digest_bytes(encoded(changes)):
        raise ValueError('Receipt does not cover the exact change set.')
    if receipt.get('engine_files') != engine_hashes(root):
        raise ValueError('Receipt does not match current combat implementation.')
    if not receipt.get('implementation_notes') or not receipt.get('tests'):
        raise ValueError('Implementation notes and test evidence required.')
    for test in receipt['tests']:
        path = (root/test['log']).resolve()
        if not path.is_relative_to(root.resolve()) or test.get('exit_code') != 0:
            raise ValueError('Tests must pass and use repository-relative evidence logs.')
        if digest_bytes(path.read_bytes()) != test.get('sha256'):
            raise ValueError('Test evidence changed or is missing.')
    # Rebuilding numeric stats cannot implement descriptions: code work must precede this checkpoint.
    scenario = build_scenario(snapshot, read(root/'design/scenarios/requested_9v9.template.json'))
    bundle = {'schema_version':1,'source_sha256':snapshot['workbook_sha256'],
              'engine_files':engine_hashes(root),'scenarios':{'requested_9v9':scenario}}
    revision = digest_bytes(encoded(bundle)); relative = f'data/runtime/bundles/{revision}.json'
    save(root/relative,bundle)
    snapshot_path = f'design/sync/snapshots/{snapshot["workbook_sha256"]}.json'
    save(root/snapshot_path,snapshot)
    save(root/'design/sync/implementation-receipt.json',receipt)
    accepted.update(workbook_sha256=snapshot['workbook_sha256'],snapshot=snapshot_path,engine_files=engine_hashes(root))
    save(root/LOCK,accepted)
    save(root/'data/runtime/active.json',{'schema_version':1,'source':WORKBOOK,
         'source_sha256':snapshot['workbook_sha256'],'bundle':relative,'bundle_sha256':revision})

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['plan','sync','check','accept'])
    parser.add_argument('--workbook',type=Path)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--receipt',type=Path,help='Engineer-reviewed implementation and test receipt; accept command only.')
    parser.add_argument('--recalculated',action='store_true',help='Attest Excel recalculated and saved formula caches; does not evaluate formulas.')
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.command=='accept':
            if not args.receipt: raise ValueError('accept requires --receipt after code and behavior checks')
            accept_review(root,args.receipt); print('IMPLEMENTATION CHECKPOINT ACCEPTED; submit through PR review'); return 0
        if args.command=='check': verify_active(root); print('SYNC CURRENT'); return 0
        workbook = (args.workbook or root/WORKBOOK).resolve()
        if args.command=='sync' and workbook != (root/WORKBOOK).resolve():
            raise ValueError('Sync reads the tracked repository workbook; copy your saved Excel there first. Use plan for external files.')
        report = run(root,workbook,args.command=='sync',args.recalculated)
        print(f'{report["state"].upper()}: {len(report["changes"])} changed cells; {report["blocker_count"]} require implementation review')
        for error in report['errors']: print(error)
        print('Details: design/sync/pending/report.json')
        return 2 if report['state']=='blocked' else 0
    except (ValueError,KeyError,FileNotFoundError) as exc:
        print('BLOCKED:',exc); return 2

if __name__=='__main__': raise SystemExit(main())
