#!/usr/bin/env python3
"""Call ppu.toys Studio MCP tools over plain HTTP. usage: studio.py TOOL [JSON-args] ; TOOL=list lists tools."""
import json, sys, os, urllib.request
URL = os.environ.get("PPU_MCP", "https://ppu.toys/api/mcp/395b4dc6bdc8f4570123f277933930502d78252f7630e1a87cdbcf3ce717b33e")
def rpc(method, params):
    req = urllib.request.Request(URL, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"content-type": "application/json", "accept": "application/json, text/event-stream", "user-agent": "curl/8.0"})
    body = urllib.request.urlopen(req, timeout=180).read().decode()
    if body.startswith("event:") or "\ndata:" in body:
        body = "".join(l[5:] for l in body.splitlines() if l.startswith("data:"))
    return json.loads(body)
def call(tool, args):
    r = rpc("tools/call", {"name": tool, "arguments": args})
    if "error" in r: return "RPC ERROR: " + json.dumps(r["error"])
    out = []
    for c in r["result"].get("content", []):
        if c.get("type") == "text": out.append(c["text"])
        elif c.get("type") == "image":
            p = os.environ.get("PPU_IMG", "/tmp/studio_shot.png")
            import base64; open(p, "wb").write(base64.b64decode(c["data"])); out.append(f"[image saved to {p}]")
        else: out.append(json.dumps(c)[:500])
    if r["result"].get("isError"): out.insert(0, "TOOL ERROR:")
    return "\n".join(out)
if __name__ == "__main__":
    if sys.argv[1] == "list":
        r = rpc("tools/list", {})
        for t in r["result"]["tools"]: print(t["name"], json.dumps(t.get("inputSchema", {}).get("properties", {}))[:400]); print()
    else:
        args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        if len(sys.argv) > 3: args[sys.argv[3]] = open(sys.argv[4]).read()   # TOOL JSON key file
        print(call(sys.argv[1], args))
