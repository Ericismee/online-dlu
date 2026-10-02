#!/usr/bin/env python3
"""version.json là chỗ duy nhất khai số bản và changelog.

Sửa version.json rồi chạy `sync`, mọi nơi khác tự ăn theo: pubspec.yaml,
lc.json (nguồn cài LiveContainer/AltStore) và app (đọc thẳng version.json).
`notes` in changelog ra markdown cho phần mô tả GitHub Release.

    tool/version.py sync [--ipa <đường-dẫn-ipa>]
    tool/version.py notes [<bản>]
    tool/version.py check <tag>     # tag có khớp version.json không
"""

from __future__ import annotations

import datetime
import json
import os
import re
import sys

GOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def doc(path=None) -> dict:
    with open(path or os.path.join(GOC, 'version.json'), encoding='utf-8') as f:
        return json.load(f)


def muc(data: dict, ban: str | None = None) -> dict:
    """Dòng changelog của [ban], mặc định là bản đang khai."""
    ban = ban or data['version']
    for m in data['changelog']:
        if m['version'] == ban:
            return m
    raise SystemExit(f'version.json chưa có changelog cho {ban}')


def notes(data: dict, ban: str | None = None) -> str:
    return '\n'.join('- ' + c for c in muc(data, ban)['changes'])


def sync(goc=GOC, ipa: str | None = None, today=None) -> dict:
    """Chép số bản + changelog từ version.json sang pubspec.yaml và lc.json."""
    data = doc(os.path.join(goc, 'version.json'))
    ten, build = data['version'], data['build']

    p = os.path.join(goc, 'pubspec.yaml')
    with open(p, encoding='utf-8') as f:
        text = f.read()
    moi = re.sub(r'(?m)^version: .*$', f'version: {ten}+{build}', text, count=1)
    if moi != text:
        with open(p, 'w', encoding='utf-8') as f:
            f.write(moi)

    p = os.path.join(goc, 'lc.json')
    with open(p, encoding='utf-8') as f:
        lc = json.load(f)
    v = lc['apps'][0]['versions'][0]
    v['version'] = ten
    v['buildVersion'] = str(build)
    # AltStore hiện một đoạn, không hiện danh sách — nối lại bằng dấu chấm đầu
    # dòng cho dễ đọc trong hộp nhỏ của nó.
    v['localizedDescription'] = '\n'.join(
        '• ' + c for c in muc(data)['changes'])
    v['date'] = muc(data).get('date') or (
        today or datetime.date.today()).isoformat()
    if ipa:
        v['size'] = os.path.getsize(ipa)
    lc['apps'][0]['version'] = ten
    with open(p, 'w', encoding='utf-8') as f:
        json.dump(lc, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return v


def demo():
    import shutil
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        for f in ('version.json', 'lc.json', 'pubspec.yaml'):
            shutil.copy(os.path.join(GOC, f), d)
        data = doc(os.path.join(d, 'version.json'))
        data['version'] = '2.4.0'
        data['build'] = 99
        data['changelog'].insert(0, {
            'version': '2.4.0',
            'date': '2026-01-02',
            'changes': ['Thêm cái này.', 'Sửa cái kia.'],
        })
        with open(os.path.join(d, 'version.json'), 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False)
        ipa = os.path.join(d, 'fake.ipa')
        open(ipa, 'wb').write(b'x' * 1234)

        v = sync(d, ipa)
        assert v['version'] == '2.4.0' and v['buildVersion'] == '99', v
        assert v['date'] == '2026-01-02' and v['size'] == 1234, v
        assert v['localizedDescription'] == '• Thêm cái này.\n• Sửa cái kia.', v
        pub = open(os.path.join(d, 'pubspec.yaml'), encoding='utf-8').read()
        assert re.search(r'(?m)^version: 2\.4\.0\+99$', pub), 'pubspec chưa đổi'
        # Mục khác của lc.json còn nguyên, và chạy lại không đổi gì thêm.
        lc = json.load(open(os.path.join(d, 'lc.json'), encoding='utf-8'))
        goc = json.load(open(os.path.join(GOC, 'lc.json'), encoding='utf-8'))
        assert lc['apps'][0]['bundleIdentifier'] == \
            goc['apps'][0]['bundleIdentifier']
        assert sync(d, ipa) == v

        assert notes(data) == '- Thêm cái này.\n- Sửa cái kia.', notes(data)
        assert notes(data, '1.0.0').startswith('- Bản đầu tiên')
    print('version ok')


if __name__ == '__main__':
    lenh = sys.argv[1] if len(sys.argv) > 1 else 'sync'
    if lenh == 'demo':
        demo()
    elif lenh == 'notes':
        print(notes(doc(), sys.argv[2] if len(sys.argv) > 2 else None))
    elif lenh == 'check':
        tag = sys.argv[2].lstrip('v')
        khai = doc()['version']
        if tag != khai:
            raise SystemExit(f'tag {tag} không khớp version.json ({khai})')
        print(f'tag khớp version.json: {khai}')
    else:
        i = sys.argv.index('--ipa') if '--ipa' in sys.argv else -1
        print(sync(ipa=sys.argv[i + 1] if i > 0 else None))
