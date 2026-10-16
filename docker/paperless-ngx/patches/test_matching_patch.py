# Checks for patches/matching.py, run inside the webserver container:
#   docker compose exec -T --user paperless webserver python3 manage.py shell \
#     -c "exec(open('/usr/src/paperless/patches/test_matching_patch.py').read())"
# Loads the patched module from the mounted patches dir (also works before the bind
# mount is active) and compares it with the image's own copy on the live taxonomy.
import importlib.machinery
import importlib.util
import json
import os

from django.contrib.auth.models import User


def load(path, name):
    loader = importlib.machinery.SourceFileLoader(name, path)  # .orig has no .py suffix
    spec = importlib.util.spec_from_loader(name, loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


here = os.environ.get("PATCH_DIR", "/usr/src/paperless/patches")
patched = load(f"{here}/matching.py", "matching_patched")
upstream = load(f"{here}/matching.py.orig", "matching_upstream")
user = User.objects.get(username="osteiner")
fails = 0


def names(objs):
    return [o.name for o in objs]


def check(label, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(f"  {'PASS' if ok else 'FAIL'} {label}: {got}" + ("" if ok else f" (want {want})"))


print("Correspondents (live taxonomy)")
C = patched.match_correspondents_by_name
check("Itaú -> Itau (accent)", names(C(["Itaú"], user)), ["Itau"])
check("EFG Bank AG -> EFG (prefix)", names(C(["EFG Bank AG"], user)), ["EFG"])
check("Swisscom (Suisse) SA -> Swisscom", names(C(["Swisscom (Suisse) SA"], user)), ["Swisscom"])
check("Itaú Unibanco S.A. -> Itau", names(C(["Itaú Unibanco S.A."], user)), ["Itau"])
check("BNP Paribas Epargne Salariale -> longest prefix",
      names(C(["BNP Paribas Epargne Salariale France"], user)), ["BNP Paribas Epargne Salariale"])
check("Telefonica Brasil S.A. -> no match (Brasil not a prefix)", names(C(["Telefonica Brasil S.A."], user)), [])
check("Bank of America -> no match (abbreviation, unchanged)", names(C(["Bank of America"], user)), [])
check("exact match still wins", names(C(["UBS"], user)), ["UBS"])
check("two names never map to one object", names(C(["Itaú", "Itau Unibanco"], user)), ["Itau"])
check("unmatched new names exclude prefix matches",
      patched.extract_unmatched_names(["EFG Bank AG", "Foo Ltd"], C(["EFG Bank AG"], user)), ["Foo Ltd"])

print("Tags / document types (no prefix rule, accents only)")
check("tag 'Health insurance' does not match tag 'Health'", names(patched.match_tags_by_name(["Health insurance"], user)), [])
check("tag 'Sucessão' -> 'Sucesão' (fuzzy, as upstream)",
      names(patched.match_tags_by_name(["Sucessão"], user)), names(upstream.match_tags_by_name(["Sucessão"], user)))
check("document type 'Déclaration de revenus' exact",
      names(patched.match_document_types_by_name(["Declaration de revenus"], user)), ["Déclaration de revenus"])

path = os.environ.get("EVAL_JSON", f"{here}/sugg_eval.json")
if os.path.exists(path):
    rows = json.load(open(path))
    print("\nReplay of the 100-document evaluation (correspondent correct)")
    for m in rows[0]["models"]:
        up = pa = 0
        for r in rows:
            x = r["models"][m]
            if "error" in x:
                continue
            picked = [i for i in x["corr"] if i not in [o.pk for o in upstream.match_correspondents_by_name(x["new_corr"], user)]]
            # model-picked IDs are unchanged by the patch; only name matching differs
            up_ids = picked + [o.pk for o in upstream.match_correspondents_by_name(x["new_corr"], user)]
            pa_ids = picked + [o.pk for o in patched.match_correspondents_by_name(x["new_corr"], user)]
            up += r["corr"] in up_ids
            pa += r["corr"] in pa_ids
        print(f"  {m:22} upstream {up}/100 -> patched {pa}/100")

print(f"\n{'ALL PASS' if not fails else f'{fails} FAILED'}")
