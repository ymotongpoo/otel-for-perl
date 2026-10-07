"""トレースごとに、期待する4スパン（Perlのサーバー、aggregate、HTTPクライアント、Goのrates）の親子関係がそろっているかを数える。"""
import json, sys, collections
sys.path.insert(0, __import__("os").path.dirname(__file__))
from trace_tree import load

spans = load(sys.argv[1])
by_trace = collections.defaultdict(list)
for s in spans:
    by_trace[s["traceId"]].append(s)

stats = collections.Counter()
for tid, ss in by_trace.items():
    perl = [s for s in ss if s["_svc"] == "report"]
    rates = [s for s in ss if s["_svc"] == "rates"]
    server = [s for s in perl if s.get("kind") == 2]
    client = [s for s in perl if s.get("kind") == 3]
    agg = [s for s in perl if s["name"] == "aggregate"]
    if not perl:
        stats["rates_only"] += 1
        continue
    ok = (len(server) == 1 and len(client) == 1 and len(agg) == 1 and len(rates) == 1
          and not server[0].get("parentSpanId")
          and agg[0].get("parentSpanId") == server[0]["spanId"]
          and client[0].get("parentSpanId") == server[0]["spanId"]
          and rates[0].get("parentSpanId") == client[0]["spanId"])
    stats["complete" if ok else "broken"] += 1
    if not ok and stats["broken"] <= 3:
        print("broken example:", tid, [(s["_svc"], s["name"], s.get("kind"), s["spanId"], s.get("parentSpanId")) for s in ss], file=sys.stderr)
print(dict(stats))
