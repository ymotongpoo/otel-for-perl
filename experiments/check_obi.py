"""OBIが作ったPerl側のスパン（service.name=perl）について、親子の対応づけを数える。
- サーバースパン1つに、同じトレースのクライアントスパンがちょうど1つあるか
- クライアントスパンの時間がサーバースパンの時間に収まるか（同時リクエストの取り違えの検出）
- Goのratesのスパンの親が、PerlのクライアントスパンになっているかHow (伝搬)"""
import sys, collections
sys.path.insert(0, __import__("os").path.dirname(__file__))
from trace_tree import load

spans = load(sys.argv[1])
perl = [s for s in spans if s["_svc"] == "perl"]
servers = {s["spanId"]: s for s in perl if s.get("kind") == 2}
clients = [s for s in perl if s.get("kind") == 3]
rates = [s for s in spans if s["_svc"] == "rates"]
by_id = {s["spanId"]: s for s in spans}

def root_server(s):
    seen = 0
    while s and s.get("kind") != 2 and seen < 10:
        s = by_id.get(s.get("parentSpanId") or "")
        seen += 1
    return s if s and s.get("kind") == 2 and s["_svc"] == "perl" else None

st = collections.Counter()
children = collections.Counter()
for c in clients:
    srv = root_server(by_id.get(c.get("parentSpanId") or ""))
    if not srv:
        st["client_without_server"] += 1
        continue
    children[srv["spanId"]] += 1
    inside = int(srv["startTimeUnixNano"]) <= int(c["startTimeUnixNano"]) and int(c["endTimeUnixNano"]) <= int(srv["endTimeUnixNano"])
    st["client_inside_parent_window" if inside else "client_outside_parent_window"] += 1
for sid in servers:
    n = children.get(sid, 0)
    st[f"server_with_{n}_clients"] += 1
client_ids = {c["spanId"] for c in clients}
for r in rates:
    st["rates_parent_is_perl_client" if (r.get("parentSpanId") in client_ids) else "rates_not_linked"] += 1
print(dict(sorted(st.items())))

# プロセス（service.instance.id）ごとの内訳
per = collections.defaultdict(collections.Counter)
for c in clients:
    per[c["_res"].get("service.instance.id")]["clients"] += 1
for r in rates:
    p = by_id.get(r.get("parentSpanId") or "")
    if p:
        per[p["_res"].get("service.instance.id")]["linked_rates"] += 1
print({k: dict(v) for k, v in sorted(per.items(), key=lambda kv: str(kv[0]))})
