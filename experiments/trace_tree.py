"""Collectorのfileエクスポーターが書いたOTLP JSON Linesから、トレースごとにスパンの木を表示する。"""
import json, sys, collections

def attrs(kv):
    out = {}
    for a in kv or []:
        v = a["value"]
        out[a["key"]] = next(iter(v.values())) if v else None
    return out

def load(path):
    spans = []
    for line in open(path, encoding="utf-8"):
        d = json.loads(line)
        for rs in d.get("resourceSpans", []):
            res = attrs(rs.get("resource", {}).get("attributes"))
            for ss in rs.get("scopeSpans", []):
                scope = ss.get("scope", {}).get("name", "")
                for s in ss.get("spans", []):
                    s["_svc"] = res.get("service.name")
                    s["_scope"] = scope
                    s["_res"] = res
                    spans.append(s)
    return spans

def main(path, keys):
    spans = load(path)
    by_trace = collections.defaultdict(list)
    for s in spans:
        by_trace[s["traceId"]].append(s)
    for tid, ss in by_trace.items():
        ids = {s["spanId"] for s in ss}
        kids = collections.defaultdict(list)
        for s in ss:
            kids[s.get("parentSpanId") or ""].append(s)
        roots = [s for s in ss if (s.get("parentSpanId") or "") not in ids]
        print(f"trace {tid} ({len(ss)} spans)")
        def show(s, depth):
            dur = (int(s["endTimeUnixNano"]) - int(s["startTimeUnixNano"])) / 1e6
            a = attrs(s.get("attributes"))
            extra = {k: a[k] for k in keys if k in a}
            st = s.get("status", {}).get("code", 0)
            print(f"  {'  '*depth}{s['_svc']}: {s['name']!r} kind={s.get('kind')} {dur:.1f}ms status={st} span={s['spanId']} parent={s.get('parentSpanId') or '-'} {extra}")
            for c in sorted(kids[s["spanId"]], key=lambda x: int(x["startTimeUnixNano"])):
                show(c, depth + 1)
        for r in sorted(roots, key=lambda x: int(x["startTimeUnixNano"])):
            show(r, 0)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
