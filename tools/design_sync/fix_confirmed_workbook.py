"""Apply the user's explicit 354-entry correction, preserving Excel formula caches."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import io
import xml.etree.ElementTree as ET
from openpyxl import load_workbook
from .pipeline import ROOT, WORKBOOK, read

def main():
    path=ROOT/WORKBOOK
    baseline=read(ROOT/read(ROOT/'design/sync/accepted.json')['snapshot'])
    ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    tag='{'+ns['s']+'}'
    raw=path.read_bytes()
    view=load_workbook(io.BytesIO(raw),data_only=False)
    sheet=view['Terminology']
    wrong={c.coordinate for row in sheet for c in row if str(c.value).strip()=='354'}
    k_cell=next('D'+str(row[0].row) for row in sheet if row[0].value=='Power Constant')
    with ZipFile(io.BytesIO(raw)) as z:
        workbook=ET.fromstring(z.read('xl/workbook.xml'))
        names=[s.attrib['name'] for s in workbook.find(tag+'sheets')]
        part='xl/worksheets/sheet'+str(names.index('Terminology')+1)+'.xml'
        xml=ET.fromstring(z.read(part))
        fixes=[]
        for cell in xml.findall('.//s:sheetData/s:row/s:c',ns):
            coord=cell.attrib['r'];val=cell.find(tag+'v')
            if coord not in wrong:continue
            old=baseline['sheets']['Terminology'].get(coord,{}).get('source')
            if old not in (None,'',' '):raise ValueError(f'Unexpected previous content at {coord}: {old}')
            for child in list(cell):cell.remove(child)
            cell.attrib.pop('t',None)
            if coord==k_cell:ET.SubElement(cell,tag+'v').text='1000'
            elif old is not None:
                cell.set('t','inlineStr');ET.SubElement(ET.SubElement(cell,tag+'is'),tag+'t').text=old
            fixes.append(coord)
        output=io.BytesIO()
        with ZipFile(output,'w',ZIP_DEFLATED) as out:
            for item in z.infolist():out.writestr(item,ET.tostring(xml,encoding='utf-8',xml_declaration=True) if item.filename==part else z.read(item.filename))
    path.write_bytes(output.getvalue())
    print('Corrected confirmed Terminology cells:',len(fixes),'K remains1000; formula caches preserved')

if __name__=='__main__':main()
