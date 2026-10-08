"""Rebuild src/ from the JSON slices that tools/export_chunk.luau returns from Studio.

Usage: python tools/assemble_export.py <slice.json> [<slice.json> ...]
The slices must be in order and the first must carry the manifest. Writes every
script under src/ (Rojo-style names) and studio-manifest.json, which maps each
file back to its instance in Studio. Exits non-zero if any script's reassembled
length differs from what Studio reported.
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "src")


def suffix(entry):
    if entry["class"] == "ModuleScript":
        return ".luau"
    if entry["class"] == "LocalScript" or entry.get("runContext") == "Client":
        return ".client.luau"
    return ".server.luau"


def main(paths):
    slices = [json.load(open(p, encoding="utf-8")) for p in paths]
    manifest = slices[0]["manifest"]
    sources = [""] * len(manifest)
    for s in slices:
        for piece in s["pieces"]:
            i = piece["i"] - 1
            if len(sources[i].encode("utf-8")) != piece["off"]:
                sys.exit(f"gap in script {piece['i']} at byte {piece['off']}")
            sources[i] += piece["text"]
    if not slices[-1]["done"]:
        sys.exit("the last slice isn't the end of the export")

    # a script with scripts inside it becomes a folder with an init file
    keys = [tuple(e["names"]) for e in manifest]
    has_children = {k for k in keys for other in keys if len(other) > len(k) and other[: len(k)] == k}

    records = []
    bad = []
    for entry, source in zip(manifest, sources):
        names = entry["names"]
        if len(source.encode("utf-8")) != entry["len"]:
            bad.append("/".join(names))
        key = tuple(names)
        if key in has_children:
            rel = os.path.join(*names, "init" + suffix(entry))
        else:
            rel = os.path.join(*names[:-1], names[-1] + suffix(entry))
        target = os.path.join(SRC, rel)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8", newline="\n") as f:
            f.write(source)
        record = {"file": "src/" + rel.replace(os.sep, "/"), "names": names, "classes": entry["classes"], "class": entry["class"]}
        for field in ("runContext", "enabled"):
            if field in entry:
                record[field] = entry[field]
        records.append(record)

    with open(os.path.join(REPO, "studio-manifest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(records, f, indent=1)
        f.write("\n")
    print(f"wrote {len(records)} scripts")
    if bad:
        sys.exit("length mismatch: " + ", ".join(bad))


if __name__ == "__main__":
    main(sys.argv[1:])
