"""Écrit les fichiers d'une tâche d'un plan.

Chaque fichier est un bloc de code précédé de la ligne `<!-- file: chemin -->`.
Usage : python tool/extract_plan.py PLAN TÂCHE [test|impl]
"""
import pathlib
import re
import sys

plan, task = sys.argv[1], sys.argv[2]
only = sys.argv[3] if len(sys.argv) > 3 else None
text = pathlib.Path(plan).read_text(encoding="utf-8")
parts = re.split(r"^### Task (\d+)\b", text, flags=re.M)
body = dict(zip(parts[1::2], parts[2::2]))[task]
for path, code in re.findall(r"<!-- file: (\S+) -->\s*```\w*\n(.*?)\n```", body, flags=re.S):
    is_test = path.startswith(("test/", "rules_test/"))
    if (only == "test" and not is_test) or (only == "impl" and is_test):
        continue
    target = pathlib.Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(code + "\n", encoding="utf-8", newline="\n")
    print("écrit", path)
