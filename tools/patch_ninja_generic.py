import pathlib

p = pathlib.Path(r"H:\Projects\SB-RFD\build\moderngekko\build.ninja")
text = p.read_text(encoding="utf-8", errors="replace")
old = "CMakeFiles\\moderngekko-run.dir\\tools\\moderngekko_run.cpp.obj"
new = "CMakeFiles\\moderngekko-run.dir\\tools\\moderngekko_run_generic.cpp.obj"
lines = text.splitlines()
changed = False
for i, line in enumerate(lines):
    if line.startswith("build SpongeBobRecompRunner.exe:") and old in line:
        lines[i] = line.replace(old, new, 1)
        changed = True
        break
if not changed:
    raise SystemExit("link line not found")
p.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("patched link line", i)
