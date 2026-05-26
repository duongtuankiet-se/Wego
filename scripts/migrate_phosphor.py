"""One-shot Material Icons -> Phosphor Icons migration for the WeGo
codebase. Walks lib/, rewrites every screen + widget that still uses
Material Icons, and patches in the phosphor_flutter import.

Run from repo root:
    py scripts/migrate_phosphor.py
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

# Ensure stdout can handle unicode on Windows cp1252 console.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent.parent / "lib"

# Material -> (Phosphor class, member)
# Pick Fill for emphatic/active visuals (location pins, fire, star, car,
# shield, airplane, etc.) and Regular for outlined/secondary visuals.
MAPPING: dict[str, tuple[str, str]] = {
    "access_time":                 ("PhosphorIconsRegular", "clock"),
    "access_time_filled":          ("PhosphorIconsFill",    "clock"),
    "account_balance_wallet_outlined": ("PhosphorIconsRegular", "wallet"),
    "add":                         ("PhosphorIconsRegular", "plus"),
    "add_circle_outline":          ("PhosphorIconsRegular", "plusCircle"),
    "add_location_alt":            ("PhosphorIconsRegular", "mapPinPlus"),
    "add_location_alt_outlined":   ("PhosphorIconsRegular", "mapPinPlus"),
    "airport_shuttle":             ("PhosphorIconsFill",    "van"),
    "airport_shuttle_rounded":     ("PhosphorIconsFill",    "van"),
    "arrow_back":                  ("PhosphorIconsRegular", "arrowLeft"),
    "arrow_downward_rounded":      ("PhosphorIconsRegular", "arrowDown"),
    "arrow_forward":               ("PhosphorIconsRegular", "arrowRight"),
    "arrow_forward_rounded":       ("PhosphorIconsRegular", "arrowRight"),
    "arrow_upward":                ("PhosphorIconsRegular", "arrowUp"),
    "arrow_upward_rounded":        ("PhosphorIconsRegular", "arrowUp"),
    "attach_money":                ("PhosphorIconsRegular", "currencyDollar"),
    "beach_access":                ("PhosphorIconsFill",    "umbrella"),
    "beach_access_outlined":       ("PhosphorIconsRegular", "umbrella"),
    "business":                    ("PhosphorIconsFill",    "briefcase"),
    "business_outlined":           ("PhosphorIconsRegular", "briefcase"),
    "cancel_outlined":             ("PhosphorIconsRegular", "xCircle"),
    "car_repair":                  ("PhosphorIconsRegular", "wrench"),
    "card_giftcard":               ("PhosphorIconsFill",    "gift"),
    "card_giftcard_outlined":      ("PhosphorIconsRegular", "gift"),
    "celebration_outlined":        ("PhosphorIconsRegular", "confetti"),
    "chat_bubble_outline":         ("PhosphorIconsRegular", "chatCircle"),
    "check":                       ("PhosphorIconsBold",    "check"),
    "check_circle":                ("PhosphorIconsFill",    "checkCircle"),
    "check_circle_outline":        ("PhosphorIconsRegular", "checkCircle"),
    "check_rounded":               ("PhosphorIconsBold",    "check"),
    "chevron_right":               ("PhosphorIconsRegular", "caretRight"),
    "chevron_right_rounded":       ("PhosphorIconsRegular", "caretRight"),
    "clear_all":                   ("PhosphorIconsRegular", "broom"),
    "close":                       ("PhosphorIconsRegular", "x"),
    "copy_outlined":               ("PhosphorIconsRegular", "copy"),
    "credit_card_outlined":        ("PhosphorIconsRegular", "creditCard"),
    "description_outlined":        ("PhosphorIconsRegular", "fileText"),
    "directions_car":              ("PhosphorIconsFill",    "car"),
    "directions_car_filled_outlined": ("PhosphorIconsRegular", "car"),
    "directions_car_outlined":     ("PhosphorIconsRegular", "car"),
    "directions_car_rounded":      ("PhosphorIconsFill",    "car"),
    "edit_outlined":               ("PhosphorIconsRegular", "pencilSimple"),
    "email_outlined":              ("PhosphorIconsRegular", "envelope"),
    "error":                       ("PhosphorIconsFill",    "warningCircle"),
    "error_outline":               ("PhosphorIconsRegular", "warningCircle"),
    "error_outline_rounded":      ("PhosphorIconsRegular", "warningCircle"),
    "expand_more":                 ("PhosphorIconsRegular", "caretDown"),
    "flight":                      ("PhosphorIconsFill",    "airplane"),
    "flight_takeoff":              ("PhosphorIconsFill",    "airplaneTakeoff"),
    "group":                       ("PhosphorIconsFill",    "usersThree"),
    "groups":                      ("PhosphorIconsFill",    "usersThree"),
    "groups_outlined":             ("PhosphorIconsRegular", "usersThree"),
    "groups_rounded":              ("PhosphorIconsFill",    "usersThree"),
    "help_outline":                ("PhosphorIconsRegular", "question"),
    "help_outline_rounded":        ("PhosphorIconsRegular", "question"),
    "home":                        ("PhosphorIconsFill",    "house"),
    "home_outlined":               ("PhosphorIconsRegular", "house"),
    "home_rounded":                ("PhosphorIconsFill",    "house"),
    "inbox_outlined":              ("PhosphorIconsRegular", "tray"),
    "info":                        ("PhosphorIconsFill",    "info"),
    "info_outline":                ("PhosphorIconsRegular", "info"),
    "landscape":                   ("PhosphorIconsFill",    "mountains"),
    "language_outlined":           ("PhosphorIconsRegular", "globe"),
    "local_fire_department":       ("PhosphorIconsFill",    "fire"),
    "local_offer_outlined":        ("PhosphorIconsRegular", "tag"),
    "location_city":               ("PhosphorIconsFill",    "buildings"),
    "location_on":                 ("PhosphorIconsFill",    "mapPin"),
    "location_on_outlined":        ("PhosphorIconsRegular", "mapPin"),
    "lock":                        ("PhosphorIconsFill",    "lock"),
    "logout":                      ("PhosphorIconsRegular", "signOut"),
    "map_outlined":                ("PhosphorIconsRegular", "mapTrifold"),
    "my_location":                 ("PhosphorIconsFill",    "crosshair"),
    "near_me":                     ("PhosphorIconsFill",    "navigationArrow"),
    "note_add":                    ("PhosphorIconsRegular", "notePencil"),
    "notifications_outlined":      ("PhosphorIconsRegular", "bell"),
    "payments_outlined":           ("PhosphorIconsRegular", "money"),
    "person":                      ("PhosphorIconsFill",    "user"),
    "person_outline":              ("PhosphorIconsRegular", "userCircle"),
    "phone":                       ("PhosphorIconsFill",    "phone"),
    "phone_outlined":              ("PhosphorIconsRegular", "phone"),
    "place_outlined":              ("PhosphorIconsRegular", "mapPin"),
    "power_off":                   ("PhosphorIconsRegular", "power"),
    "power_settings_new":          ("PhosphorIconsFill",    "power"),
    "refresh":                     ("PhosphorIconsRegular", "arrowsClockwise"),
    "restart_alt":                 ("PhosphorIconsRegular", "arrowsCounterClockwise"),
    "school":                      ("PhosphorIconsFill",    "graduationCap"),
    "search":                      ("PhosphorIconsRegular", "magnifyingGlass"),
    "search_off":                  ("PhosphorIconsRegular", "magnifyingGlassMinus"),
    "send_outlined":               ("PhosphorIconsRegular", "paperPlaneRight"),
    "settings_outlined":           ("PhosphorIconsRegular", "gear"),
    "share_outlined":              ("PhosphorIconsRegular", "shareNetwork"),
    "shield":                      ("PhosphorIconsFill",    "shield"),
    "shield_outlined":             ("PhosphorIconsRegular", "shield"),
    "star":                        ("PhosphorIconsFill",    "star"),
    "star_outline_rounded":        ("PhosphorIconsRegular", "star"),
    "star_rounded":                ("PhosphorIconsFill",    "star"),
    "store":                       ("PhosphorIconsFill",    "shoppingBag"),
    "storefront":                  ("PhosphorIconsFill",    "storefront"),
    "straighten":                  ("PhosphorIconsRegular", "ruler"),
    "support_agent":               ("PhosphorIconsFill",    "headset"),
    "support_agent_outlined":      ("PhosphorIconsRegular", "headset"),
    "touch_app":                   ("PhosphorIconsRegular", "handTap"),
    "trending_up":                 ("PhosphorIconsRegular", "trendUp"),
    "tune":                        ("PhosphorIconsRegular", "faders"),
    "turn_left":                   ("PhosphorIconsRegular", "arrowBendUpLeft"),
    "turn_right":                  ("PhosphorIconsRegular", "arrowBendUpRight"),
    "two_wheeler":                 ("PhosphorIconsFill",    "motorcycle"),
    "visibility":                  ("PhosphorIconsRegular", "eye"),
    "visibility_off":              ("PhosphorIconsRegular", "eyeSlash"),
    "volume_off":                  ("PhosphorIconsRegular", "speakerSlash"),
    "volume_up_outlined":          ("PhosphorIconsRegular", "speakerHigh"),
    "warning_amber_rounded":       ("PhosphorIconsFill",    "warning"),
    "weekend_outlined":            ("PhosphorIconsRegular", "couch"),
}

PHOSPHOR_IMPORT = "import 'package:phosphor_flutter/phosphor_flutter.dart';\n"

# Sort longer keys first so "access_time_filled" doesn't get pre-matched
# by "access_time".
SORTED_KEYS = sorted(MAPPING.keys(), key=len, reverse=True)
PATTERN = re.compile(
    r"\bIcons\.(" + "|".join(re.escape(k) for k in SORTED_KEYS) + r")\b"
)


def add_import(content: str) -> str:
    """Insert phosphor_flutter import right after the last package: import."""
    if "phosphor_flutter/phosphor_flutter.dart" in content:
        return content
    lines = content.split("\n")
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith("import 'package:") or line.startswith("import \"package:"):
            last_import = i
    if last_import == -1:
        return PHOSPHOR_IMPORT + content
    lines.insert(last_import + 1, PHOSPHOR_IMPORT.rstrip("\n"))
    return "\n".join(lines)


def migrate_file(path: Path) -> tuple[int, list[str]]:
    text = path.read_text(encoding="utf-8")
    misses: list[str] = []
    matches = PATTERN.findall(text)
    if not matches:
        # Check for any leftover Icons.x not in our mapping
        for m in re.finditer(r"\bIcons\.([a-z_]+)\b", text):
            if m.group(1) not in MAPPING:
                misses.append(m.group(1))
        return 0, sorted(set(misses))

    def repl(match: re.Match) -> str:
        name = match.group(1)
        cls, member = MAPPING[name]
        return f"{cls}.{member}"

    new_text = PATTERN.sub(repl, text)
    # Surface any Icons.x left behind (unmapped)
    for m in re.finditer(r"\bIcons\.([a-z_]+)\b", new_text):
        if m.group(1) not in MAPPING:
            misses.append(m.group(1))

    new_text = add_import(new_text)
    path.write_text(new_text, encoding="utf-8")
    return len(matches), sorted(set(misses))


def main() -> None:
    total = 0
    files_touched = 0
    all_misses: dict[str, set[str]] = {}
    for path in ROOT.rglob("*.dart"):
        if path.name.endswith(".g.dart") or path.name.endswith(".freezed.dart"):
            continue
        count, misses = migrate_file(path)
        if count:
            print(f"✓ {path.relative_to(ROOT.parent)}: {count} replaced")
            files_touched += 1
            total += count
        if misses:
            all_misses[str(path.relative_to(ROOT.parent))] = set(misses)

    print(f"\nTotal replacements: {total} across {files_touched} files.")
    if all_misses:
        print("\nUnmapped Material Icons leftover (need manual review):")
        for f, m in all_misses.items():
            print(f"  {f}: {sorted(m)}")
    else:
        print("All Material Icons usage mapped to Phosphor.")


if __name__ == "__main__":
    main()
