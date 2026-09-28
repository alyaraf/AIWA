"""Checks lib/l10n/app_en.arb and app_ar.arb have the same keys and that no
Arabic value is still identical to the English one (untranslated).
Run from the app root: python tool/check_arb.py"""
import json, sys

def keys(f):
    d = json.load(open(f'lib/l10n/{f}', encoding='utf-8'))
    return {k: v for k, v in d.items() if not k.startswith('@')}

en, ar = keys('app_en.arb'), keys('app_ar.arb')
missing_ar, missing_en = en.keys() - ar.keys(), ar.keys() - en.keys()
# Values that are fine to share: brand, currency code in a label, pure formats.
same = [k for k in en.keys() & ar.keys()
        if en[k] == ar[k] and k not in ('searchMinRatingChip',)]
print(f'en keys: {len(en)}  ar keys: {len(ar)}')
print(f'missing in ar: {sorted(missing_ar) or "none"}')
print(f'missing in en: {sorted(missing_en) or "none"}')
print(f'ar identical to en: {same or "none"}')
sys.exit(1 if missing_ar or missing_en or same else 0)
