#!/usr/bin/env python3
"""List the keys the app passes to tr(...) and which of them Resources/Localization/en.json lacks.

    python3 scripts/l10n_keys.py          # report missing keys and Thai literals that are not wrapped
    python3 scripts/l10n_keys.py --dump   # print every key as JSON
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THAI = re.compile(r'[฀-๿]')
CALL = re.compile(r'\btr\("((?:[^"\\]|\\.)*)"')

def unescape(raw):
    return (raw.replace('\\n', '\n').replace('\\t', '\t').replace('\\"', '"').replace('\\\\', '\\'))

def keys():
    found = {}
    for path in sorted(glob.glob(f'{ROOT}/Sources/*/*.swift')):
        for m in CALL.finditer(open(path, encoding='utf-8').read()):
            found.setdefault(unescape(m.group(1)), os.path.relpath(path, ROOT))
    return found

if __name__ == '__main__':
    found = keys()
    if '--dump' in sys.argv:
        print(json.dumps(sorted(found), ensure_ascii=False, indent=1)); sys.exit(0)
    table_path = f'{ROOT}/Resources/Localization/en.json'
    table = json.load(open(table_path, encoding='utf-8')) if os.path.exists(table_path) else {}
    missing = [k for k in found if k not in table]
    unused = [k for k in table if k not in found]
    print(f'{len(found)} keys, {len(missing)} missing, {len(unused)} unused')
    for k in missing: print('MISSING', found[k], repr(k))
    for k in unused: print('UNUSED', repr(k))
    sys.exit(1 if missing else 0)
