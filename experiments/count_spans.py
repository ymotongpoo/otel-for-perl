"""otlp.jsonlのスパン数をservice.nameごとに数える。"""
import json, sys, collections
c = collections.Counter()
try:
    for line in open(sys.argv[1], encoding="utf-8"):
        for rs in json.loads(line).get("resourceSpans", []):
            svc = next((a["value"].get("stringValue") for a in rs["resource"].get("attributes", []) if a["key"] == "service.name"), None)
            c[svc] += sum(len(ss.get("spans", [])) for ss in rs.get("scopeSpans", []))
except FileNotFoundError:
    pass
print(dict(c))
