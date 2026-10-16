# TARGET: /usr/src/paperless/src/paperless_ai/matching.py
# LOCAL PATCH of paperless-ngx 3.3.1 src/paperless_ai/matching.py (dotfiles
# docker/paperless-ngx/patches/, bind-mounted read-only over the image's copy).
# Based on upstream sha256 e877683fdc0fc29af2561d562b739f961a23bdb3d633701f1c90107663731fec;
# `upgrade-tests.sh patches` fails when the image's file no longer has that hash.
# Changes, all marked "LOCAL PATCH" below:
#   1. _normalize ignores accents and turns punctuation into spaces (Itaú == Itau).
#   2. Correspondents only: a model name that starts with an existing name as whole
#      words matches it ("EFG Bank AG" -> EFG), and an existing name that starts with
#      the model's name matches when that is unambiguous ("Helsana" -> "Helsana AG").
#   3. extract_unmatched_names drops names matched by rule 2, so they aren't also
#      offered as new correspondents.
import difflib
import logging
import re
import unicodedata
from typing import TypeVar

from django.contrib.auth.models import User
from django.db.models import Model
from django.db.models import QuerySet

from documents.models import Correspondent
from documents.models import DocumentType
from documents.models import StoragePath
from documents.models import Tag
from documents.permissions import permitted_object_ids
from documents.permissions import restrict_queryset_to_visible

MATCH_THRESHOLD = 0.8

logger = logging.getLogger("paperless_ai.matching")

ModelT = TypeVar("ModelT", bound=Model)


def _resolve_visible_ids(
    ids: list[int],
    user: User | None,
    model: type[ModelT],
    perm: str,
) -> list[ModelT]:
    """Resolve model-returned IDs against what the user may currently see.
    Invalid, deleted, or now-invisible IDs are silently dropped - the model's
    belief that an ID exists and is visible may be stale by the time the
    response comes back.
    """
    if not ids:
        return []
    queryset = restrict_queryset_to_visible(
        model.objects.filter(pk__in=ids),
        user,
        perm,
    )
    return list(queryset)


def resolve_tag_ids(ids: list[int], user: User | None) -> list[Tag]:
    return _resolve_visible_ids(ids, user, Tag, "view_tag")


def resolve_correspondent_ids(
    ids: list[int],
    user: User | None,
) -> list[Correspondent]:
    return _resolve_visible_ids(ids, user, Correspondent, "view_correspondent")


def resolve_document_type_ids(ids: list[int], user: User | None) -> list[DocumentType]:
    return _resolve_visible_ids(ids, user, DocumentType, "view_documenttype")


def resolve_storage_path_ids(ids: list[int], user: User | None) -> list[StoragePath]:
    return _resolve_visible_ids(ids, user, StoragePath, "view_storagepath")


def _match_by_name(
    names: list[str],
    user: User | None,
    model: type[ModelT],
    perm: str,
) -> list[ModelT]:
    # A workflow may have no user. In that case permitted_object_ids limits
    # matching to unowned objects, avoiding another user's private taxonomy.
    queryset = model.objects.filter(
        pk__in=permitted_object_ids(user, model, perm),
    )
    # LOCAL PATCH: whole-word prefix matching for correspondents only
    return _match_names_to_queryset(names, queryset, prefix=model is Correspondent)


def match_tags_by_name(names: list[str], user: User | None) -> list[Tag]:
    return _match_by_name(names, user, Tag, "view_tag")


def match_correspondents_by_name(
    names: list[str],
    user: User | None,
) -> list[Correspondent]:
    return _match_by_name(names, user, Correspondent, "view_correspondent")


def match_document_types_by_name(
    names: list[str],
    user: User | None,
) -> list[DocumentType]:
    return _match_by_name(names, user, DocumentType, "view_documenttype")


def match_storage_paths_by_name(
    names: list[str],
    user: User | None,
) -> list[StoragePath]:
    return _match_by_name(names, user, StoragePath, "view_storagepath")


def _normalize(s: str) -> str:
    # LOCAL PATCH: strip accents, and turn punctuation into spaces so that
    # "Swisscom (Suisse) SA" / "S.A." split into words for prefix matching.
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    s = re.sub(r"[^\w\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


# LOCAL PATCH: shortest existing name usable as a whole-word prefix.
PREFIX_MIN_LEN = 3


def _prefix_index(target: str, object_names: list[str]) -> int | None:
    """LOCAL PATCH. The longest existing name that the model's name starts with
    as whole words ("efg bank ag" -> "efg"); otherwise the single existing name
    that starts with the model's name ("helsana" -> "helsana ag"), if unambiguous.
    """
    forward = [
        i
        for i, o in enumerate(object_names)
        if len(o) >= PREFIX_MIN_LEN and target.startswith(o + " ")
    ]
    if forward:
        return max(forward, key=lambda i: len(object_names[i]))
    if len(target) >= 4:
        reverse = [i for i, o in enumerate(object_names) if o.startswith(target + " ")]
        if len(reverse) == 1:
            return reverse[0]
    return None


def _same_entity(a: str, b: str) -> bool:
    """LOCAL PATCH: normalized names equal, or one is a whole-word prefix of the other."""
    return a == b or (
        min(len(a), len(b)) >= PREFIX_MIN_LEN
        and (a.startswith(b + " ") or b.startswith(a + " "))
    )


def _match_names_to_queryset(
    names: list[str],
    queryset: QuerySet[ModelT],
    attr: str = "name",
    prefix: bool = False,  # LOCAL PATCH
) -> list[ModelT]:
    """Match each name to at most one object, exactly first and fuzzily as a
    fallback. A matched object is removed from the pool so two names can never
    resolve to the same object; names that match nothing are simply skipped.
    """
    results: list[ModelT] = []
    objects = list(queryset)
    object_names = [_normalize(getattr(obj, attr)) for obj in objects]

    for name in names:
        if not name:
            continue
        target = _normalize(name)

        if target in object_names:
            index = object_names.index(target)
        else:
            matches = difflib.get_close_matches(
                target,
                object_names,
                n=1,
                cutoff=MATCH_THRESHOLD,
            )
            if matches:
                index = object_names.index(matches[0])
            else:
                # LOCAL PATCH: whole-word prefix fallback (correspondents only)
                index = _prefix_index(target, object_names) if prefix else None
                if index is None:
                    continue

        object_names.pop(index)  # keep both lists aligned after removal
        results.append(objects.pop(index))
    return results


def extract_unmatched_names(
    names: list[str],
    matched_objects: list,
    attr="name",
) -> list[str]:
    matched_names = {_normalize(getattr(obj, attr)) for obj in matched_objects}
    # LOCAL PATCH: also drop names matched through a whole-word prefix
    return [
        name
        for name in names
        if not any(_same_entity(_normalize(name), m) for m in matched_names)
    ]
