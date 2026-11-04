import copy
import json
import tempfile
import unittest
from pathlib import Path
from openpyxl import Workbook, load_workbook
from tools.design_sync.pipeline import (FIELDS, WORKBOOK, LOCK, extract, save, encoded,
    digest_bytes, engine_hashes, run, verify_active, classify, accept_review)

class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);r=self.root
        (r/'src/combat').mkdir(parents=True);(r/'src/combat/engine.gd').write_text('extends RefCounted\n')
        self.book=r/WORKBOOK;self.book.parent.mkdir(parents=True)
        w=Workbook();s=w.active;s.title='Warrior class';s['B2']='Test warrior'
        for row,label in enumerate(FIELDS,9): s.cell(row,1,label);s.cell(row,2,100);s.cell(row,3,50)
        s['A32']='Test Skill - 5';s['B32']=100;s['C32']=50;s['D32']=3;s['E32']='Deals damage'
        w.create_sheet('Combat Mechanics')['A1']='Rules'
        w.save(self.book)
        snapshot=extract(self.book);self.base=snapshot
        save(r/'design/sync/base.json',snapshot)
        save(r/LOCK,{'workbook_sha256':snapshot['workbook_sha256'],'snapshot':'design/sync/base.json','engine_files':engine_hashes(r)})
        self.template={'roster':[{'type':'Warrior','nodes':[],'skills':{'Test Skill':{'sheet_row':32,'ap':100,'mp':50,'cd':3}}}]}
        save(r/'design/scenarios/requested_9v9.template.json',self.template)
        self.assertEqual(run(r,self.book,True)['state'],'ready')

    def edit(self,sheet,cell,value):
        w=load_workbook(self.book);w[sheet][cell]=value;w.save(self.book);w.close()

    def test_unchanged_idempotent(self):
        first=(self.root/'data/runtime/active.json').read_bytes()
        run(self.root,self.book,True)
        self.assertEqual(first,(self.root/'data/runtime/active.json').read_bytes())
        verify_active(self.root)

    def test_numeric_stat_reaches_existing_scenario(self):
        self.edit('Warrior class','B9',999)
        report=run(self.root,self.book,True,True)
        self.assertEqual(report['state'],'ready')
        active=verify_active(self.root)
        bundle=json.loads((self.root/active['bundle']).read_bytes())
        self.assertEqual(bundle['scenarios']['requested_9v9']['roster'][0]['max_hp'],999)

    def test_cost_update(self):
        self.edit('Warrior class','C32',77)
        self.assertEqual(run(self.root,self.book,True,True)['state'],'ready')
        active=verify_active(self.root);bundle=json.loads((self.root/active['bundle']).read_bytes())
        self.assertEqual(bundle['scenarios']['requested_9v9']['roster'][0]['skills']['Test Skill']['mp'],77)

    def test_mechanic_blocks_without_overwriting_active(self):
        before=(self.root/'data/runtime/active.json').read_bytes()
        self.edit('Combat Mechanics','A1','A new HP decay mechanic')
        report=run(self.root,self.book,True,True)
        self.assertEqual(report['state'],'blocked')
        self.assertEqual(before,(self.root/'data/runtime/active.json').read_bytes())
        with self.assertRaises(ValueError):verify_active(self.root)

    def test_formula_is_not_executed(self):
        self.edit('Warrior class','B9','=1+999')
        report=run(self.root,self.book,True,True)
        self.assertEqual(report['state'],'blocked')
        self.assertTrue(report['errors'])

    def test_engine_change_blocks(self):
        (self.root/'src/combat/engine.gd').write_text('extends RefCounted\n# changed')
        self.assertEqual(run(self.root,self.book,True)['state'],'blocked')
        with self.assertRaises(ValueError):verify_active(self.root)

    def test_bundle_tampering_detected(self):
        active=verify_active(self.root);(self.root/active['bundle']).write_text('{}')
        with self.assertRaises(ValueError):verify_active(self.root)

    def test_windows_line_endings_do_not_change_engine_revision(self):
        (self.root/'src/combat/engine.gd').write_bytes(b'extends RefCounted\r\n')
        verify_active(self.root)

    def test_review_receipt_cannot_be_empty(self):
        save(self.root/'receipt.json',{})
        with self.assertRaises(ValueError):accept_review(self.root,self.root/'receipt.json')

    def test_effect_cache_is_not_silently_a_stat(self):
        change={'sheet':'Warrior class','cell':'K32','before':{'source':'=100*5','value':500},'after':{'source':'=100*5','value':600}}
        self.assertEqual(classify(change,self.base),'review_effect_cache')

    def test_negative_hp_blocked(self):
        self.edit('Warrior class','B9',-1)
        self.assertEqual(run(self.root,self.book,True,True)['state'],'blocked')

    def test_valid_implementation_receipt(self):
        self.edit('Combat Mechanics','A1','New implemented rule')
        snapshot=extract(self.book)
        from tools.design_sync.pipeline import differences
        evidence=self.root/'artifacts/test.log';evidence.parent.mkdir();evidence.write_text('PASS')
        receipt={'source_sha256':snapshot['workbook_sha256'],
                 'reviewed_change_sha256':digest_bytes(encoded(differences(self.base,snapshot))),
                 'engine_files':engine_hashes(self.root),'implementation_notes':'Reviewed fixture rule',
                 'tests':[{'command':'fixture test','exit_code':0,'log':'artifacts/test.log','sha256':digest_bytes(evidence.read_bytes())}]}
        save(self.root/'receipt.json',receipt)
        accept_review(self.root,self.root/'receipt.json')
        verify_active(self.root)

    def test_two_characters_share_sheet_without_sharing_stat_block(self):
        template=copy.deepcopy(self.template)
        second=copy.deepcopy(template['roster'][0])
        second['design_binding']={'sheet':'Warrior class','stat_start':50,'name_cell':'B43'}
        second['name']='Second caster';template['roster'].append(second)
        wb=load_workbook(self.book);sh=wb['Warrior class'];sh['B43']='Second caster'
        for row,label in enumerate(FIELDS,50):sh.cell(row,1,label);sh.cell(row,2,200);sh.cell(row,3,80)
        wb.save(self.book);wb.close()
        from tools.design_sync.pipeline import build_scenario
        result=build_scenario(extract(self.book),template)
        self.assertEqual(result['roster'][0]['max_hp'],100)
        self.assertEqual(result['roster'][1]['max_hp'],200)
        self.assertEqual(result['roster'][1]['character_ap_recovery'],80)

if __name__=='__main__':unittest.main()
