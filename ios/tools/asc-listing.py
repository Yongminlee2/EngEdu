# store/앱스토어-작성내용.md 의 언어별 칸(이름·부제·키워드·프로모션·설명)을 JSON 으로 뽑는다 — App Store Connect 에 넣을 때 쓴다.
#   python3 ios/tools/asc-listing.py store/앱스토어-작성내용.md store/appstore-listing.json
import re, json, sys
src, out = sys.argv[1], sys.argv[2]
t = open(src, encoding='utf-8').read()
secs = re.split(r'\n### ', t)
res = {}
for s in secs:
    m = re.match(r'.*?\(`([a-zA-Z-]+)`\)', s.split('\n')[0])
    if not m: continue
    loc = m.group(1)
    def field(label):
        mm = re.search(r'\*\*' + label + r'\*\*[^\n]*\n```\n(.*?)\n```', s, re.S)
        return mm.group(1) if mm else None
    d = {'name': field('이름'), 'subtitle': field('부제'), 'keywords': field('키워드'),
         'promo': field('프로모션 텍스트'), 'description': field('설명')}
    if d['name']: res[loc] = d
json.dump(res, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(res), list(res))
for k, v in res.items():
    print(k, [len(x or '') for x in v.values()])
