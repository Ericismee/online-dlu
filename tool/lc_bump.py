#!/usr/bin/env python3
"""Ghi phiên bản mới vào lc.json — nguồn cài LiveContainer/AltStore.

Máy người dùng chỉ hiện nút cập nhật khi 'version' trong lc.json nhích lên,
nên mỗi lần phát hành phải chạy cái này, không thì file mới nằm im trên
Releases mà không ai biết.

    tool/lc_bump.py <đường-dẫn-ipa> <tag> [lc.json]
"""

import datetime
import json
import os
import sys


def bump(path: str, tag: str, ipa: str, today=None) -> dict:
    name, _, build = tag.lstrip('v').partition('+')
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    version = data['apps'][0]['versions'][0]
    version['version'] = name
    if build:
        version['buildVersion'] = build
    version['date'] = (today or datetime.date.today()).isoformat()
    version['size'] = os.path.getsize(ipa)
    # AltStore chỉ cần bản mới nhất, nhưng app có màn 'Cập nhật' liệt kê mọi
    # bản — ghi thêm vào đây để khỏi phải gõ changelog ở chỗ thứ hai.
    lich_su = data.setdefault('changelog', [])
    if not any(m['version'] == name for m in lich_su):
        lich_su.insert(0, {
            'version': name,
            'date': version['date'],
            'text': version['localizedDescription'],
        })
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return version


def demo():
    import tempfile
    src = json.load(open('lc.json', encoding='utf-8'))
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, 'lc.json')
        json.dump(src, open(p, 'w', encoding='utf-8'), ensure_ascii=False)
        ipa = os.path.join(d, 'fake.ipa')
        open(ipa, 'wb').write(b'x' * 1234)
        v = bump(p, 'v2.3.4+7', ipa, today=datetime.date(2026, 1, 2))
        assert v['version'] == '2.3.4', v
        assert v['buildVersion'] == '7', v
        assert v['date'] == '2026-01-02', v
        assert v['size'] == 1234, v
        # Tag không có buildVersion thì giữ nguyên số cũ, đừng xoá.
        v = bump(p, 'v2.4.0', ipa, today=datetime.date(2026, 1, 2))
        assert v['version'] == '2.4.0' and v['buildVersion'] == '7', v
        # Đọc lại được và các mục khác còn nguyên.
        back = json.load(open(p, encoding='utf-8'))
        # Mỗi bản một dòng lịch sử, mới nhất lên đầu, chạy lại không nhân đôi.
        cu = len(src.get('changelog', []))
        assert [m['version'] for m in back['changelog'][:2]] == \
            ['2.4.0', '2.3.4'], back['changelog']
        assert len(back['changelog']) == cu + 2, back['changelog']
        bump(p, 'v2.4.0', ipa, today=datetime.date(2026, 1, 2))
        back = json.load(open(p, encoding='utf-8'))
        assert len(back['changelog']) == cu + 2, back['changelog']
        assert back['apps'][0]['bundleIdentifier'] == \
            src['apps'][0]['bundleIdentifier']
    print('lc_bump ok')


if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == 'demo':
        demo()
    else:
        ipa, tag = sys.argv[1], sys.argv[2]
        path = sys.argv[3] if len(sys.argv) > 3 else 'lc.json'
        print(bump(path, tag, ipa))
