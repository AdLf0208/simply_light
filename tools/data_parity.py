#!/usr/bin/env python3
"""Carried-data parity for Simply Light, driven from the delivered `.hmod`.

Called by `tools/data_parity.sh` with the open game's control socket and the
package path. Reads the recipes, item tags and loot tables **out of the
delivered archive** (not out of the working tree), so the bytes under test are
the bytes that ship, and then:

1. crafts every recipe in a real crafting table — `data/simplylight/recipe/*.json`
   (234 at 0.2.0) — placing each pattern / shapeless list on the harness grid
   (slots 100-108, result 200), and asserts, per recipe:
     - the result slot holds exactly the declared `result.id` and `result.count`;
     - shift-clicking the result empties every ingredient cell (the ingredients
       were consumed);
     - the inventory then holds exactly `count - cells that used the result item`
       of the result item (a no-loss recolour holds its count, a conversion
       changes it);
2. rolls every loot table — `data/simplylight/loot_table/blocks/*.json` (160) —
   with `/loot give @s loot simplylight:blocks/<name>` and asserts the player
   received exactly one of that block and nothing else (every block drops
   itself), plus that an unknown table is refused (the control).

Tag ingredients are resolved from the package's own `tags/item/*` and
`data/c/tags/item/**` files, falling back to a documented vanilla member only
for `#minecraft:walls` (vanilla data, not shipped by this package). A recipe
whose tag resolves to nothing is a failure, not a skip: it would be dead data.

`PARITY_SELFTEST=1` expects one extra item of the first recipe's result, so the
run MUST exit 1 (the assertion is live). `PARITY_ONLY=<name>` and
`PARITY_LIMIT=<n>` bound a debugging run.
"""
import json
import os
import re
import subprocess
import sys
import zipfile

# Vanilla tags this package does not ship; one documented member each.
VANILLA_TAGS = {
    "#minecraft:walls": "minecraft:cobblestone_wall",
}
GRID = list(range(100, 109))
RESULT = 200


def die(message):
    raise SystemExit(message)


class Game:
    def __init__(self, ctl, sock):
        self.ctl = ctl
        self.sock = sock

    def __call__(self, *args):
        out = subprocess.run([self.ctl, "--socket", self.sock, *args],
                             text=True, capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            die(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(self, ticks=1):
        self("wait", str(ticks))

    def slots(self):
        screen = self("screen")
        if "slots" not in screen:
            die(f"no menu is open: {screen}")
        return {int(s["slot"]): s for s in screen["slots"]}

    def items(self):
        counts = self("inventory").get("counts") or {}
        return {k: v for k, v in counts.items() if v}


def tag_values(package, name):
    """Every member of an item tag, from the package's own tag files."""
    path = "data/" + name.split(":")[0] + "/tags/item/" + name.split(":")[1] + ".json"
    if path in package.namelist():
        raw = json.loads(package.read(path))
        values = []
        for value in raw.get("values", []):
            if isinstance(value, dict):
                value = value.get("id", "")
            if value.startswith("#"):
                values.extend(tag_values(package, value[1:]))
            elif value:
                values.append(value)
        return values
    return []


def representative(package, ingredient):
    """The concrete item a tag ingredient is crafted with."""
    if not ingredient.startswith("#"):
        return ingredient
    tag = ingredient[1:]
    values = [v for v in tag_values(package, tag) if not v.startswith("#")]
    if values:
        # `#c:stones` and the `#simplylight:any_*` families: the first member is
        # the family's uncoloured item, which is the one a player would use.
        return values[0]
    if ingredient in VANILLA_TAGS:
        return VANILLA_TAGS[ingredient]
    die(f"tag {ingredient} resolves to no item in the package and has no documented member")


def cells(package, recipe):
    """[(grid slot, item id)] for one recipe, in the recipe's own shape."""
    kind = recipe["type"]
    if kind == "minecraft:crafting_shaped":
        key = recipe["key"]
        out = []
        for y, row in enumerate(recipe["pattern"]):
            for x, char in enumerate(row):
                if char == " ":
                    continue
                out.append((100 + y * 3 + x, representative(package, key[char])))
        return out
    if kind == "minecraft:crafting_shapeless":
        ingredients = [representative(package, ing) for ing in recipe["ingredients"]]
        if len(ingredients) > 9:
            die(f"shapeless recipe with {len(ingredients)} ingredients does not fit the grid")
        return [(100 + i, item) for i, item in enumerate(ingredients)]
    die(f"recipe type {kind} is not a crafting-table recipe")


def load(package_path):
    package = zipfile.ZipFile(package_path)
    recipes = {}
    for name in package.namelist():
        if name.startswith("data/simplylight/recipe/") and name.endswith(".json"):
            recipes[name.rsplit("/", 1)[-1][:-5]] = json.loads(package.read(name))
    loot = {}
    for name in package.namelist():
        if name.startswith("data/simplylight/loot_table/blocks/") and name.endswith(".json"):
            loot[name.rsplit("/", 1)[-1][:-5]] = json.loads(package.read(name))
    return package, recipes, loot


def open_table(game, pos):
    game("close")
    game.wait(2)
    game("interact", *[str(v) for v in pos])
    game.wait(2)
    slots = game.slots()
    if RESULT not in slots:
        die("the crafting table did not open (no result slot)")


def clean_grid(game):
    """Move any leftover ingredient back to the inventory, then empty it."""
    slots = game.slots()
    for slot in GRID:
        if slots.get(slot, {}).get("item"):
            game("click-slot", str(slot), "shift")
            game.wait(1)
    game("command", "clear @s")
    game.wait(1)


def place(game, item, targets):
    slots = game.slots()
    slot = None
    for candidate in GRID + list(range(0, 36)) + [504]:
        if slots.get(candidate, {}).get("item") == item:
            slot = candidate
            break
    if slot is None:
        die(f"missing ingredient {item} in the inventory")
    game("click-slot", str(slot))
    game.wait(1)
    for target in targets:
        game("click-slot", str(target), "right")
        game.wait(1)
    game("click-slot", str(slot))
    game.wait(1)


def craft(game, package, name, recipe, selftest=False):
    """One recipe; returns None or a failure string."""
    plan = cells(package, recipe)
    want = recipe["result"]
    want_count = want["count"] + (1 if selftest else 0)
    clean_grid(game)
    counts = {}
    for _, item in plan:
        counts[item] = counts.get(item, 0) + 1
    for item, count in counts.items():
        game("give", item, str(count))
    game.wait(2)
    by_item = {}
    for slot, item in plan:
        by_item.setdefault(item, []).append(str(slot))
    for item, targets in by_item.items():
        place(game, item, targets)
    game.wait(2)

    slots = game.slots()
    result = slots.get(RESULT, {})
    got = (result.get("item"), result.get("count"))
    if got != (want["id"], want_count):
        return (f"{name}: expected result {want_count} {want['id']}, "
                f"got {got}")

    game("click-slot", str(RESULT), "shift")
    game.wait(2)
    slots = game.slots()
    left = {slot: slots[slot].get("item") for slot in GRID if slots.get(slot, {}).get("item")}
    if left:
        return f"{name}: the ingredients were not consumed, grid still holds {left}"
    if slots.get(RESULT, {}).get("item"):
        return f"{name}: the result slot still holds {slots[RESULT].get('item')}"

    # The ingredients were given in exactly the amount the grid used, so the
    # inventory reads: given - consumed + produced = produced. A recipe that
    # consumed nothing would read twice the result count, which this catches.
    used = sum(1 for _, item in plan if item == want["id"])
    expected = want["count"]
    got_count = game.items().get(want["id"], 0)
    if got_count != expected:
        return (f"{name}: the inventory holds {got_count} {want['id']} after crafting, "
                f"expected {expected} ({want['count']} made, {used} given as ingredients; "
                f"an unconsumed grid would read {want['count'] + used})")
    return None


def loot(game, package, name):
    """One loot table; returns None or a failure string."""
    item = "simplylight:" + name
    game("command", "clear @s")
    game.wait(1)
    reply = game("command", f"loot give @s loot simplylight:blocks/{name}")
    if not reply.get("ok", True):
        return f"{name}: /loot refused the table: {reply}"
    game.wait(2)
    got = game.items()
    if got != {item: 1}:
        return f"{name}: the table gave {got}, expected {{{item!r}: 1}}"
    return None


def main():
    sock, ctl, package_path, table = sys.argv[1:5]
    table = [int(v) for v in table.split(",")]
    game = Game(ctl, sock)
    package, recipes, loots = load(package_path)
    selftest = os.environ.get("PARITY_SELFTEST") == "1"
    only = os.environ.get("PARITY_ONLY")
    limit = int(os.environ.get("PARITY_LIMIT") or 0)

    names = sorted(recipes)
    if only:
        names = [n for n in names if only in n]
    if limit:
        names = names[:limit]
    if not names:
        die("no recipes selected")

    open_table(game, table)
    failures = []
    for index, name in enumerate(names, 1):
        failure = craft(game, package, name, recipes[name], selftest=selftest and index == 1)
        want = recipes[name]["result"]
        print(f"[{index}/{len(names)}] {name}: {want['count']} {want['id']} "
              f"({'FAIL' if failure else 'ok'})", flush=True)
        if failure:
            if selftest and index == 1:
                # The deliberately wrong expectation must trip on the first recipe.
                game("close")
                print(f"FAIL: SELFTEST: {failure}", file=sys.stderr)
                raise SystemExit(1)
            failures.append(failure)
            clean_grid(game)
    if failures:
        game("close")
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(f"recipes PASS: {len(names)}/{len(names)} carried recipes craft their declared "
          f"result id and count, every ingredient is consumed, and the output lands in the "
          f"inventory", flush=True)

    names = sorted(loots)
    failures = []
    for index, name in enumerate(names, 1):
        failure = loot(game, package, name)
        print(f"[{index}/{len(names)}] loot {name} ({'FAIL' if failure else 'ok'})", flush=True)
        if failure:
            failures.append(failure)
    game("command", "clear @s")
    unknown = game("command", "loot give @s loot simplylight:blocks/not_a_block")
    print(f"unknown table: {json.dumps(unknown)}", flush=True)
    got = game.items()
    if got:
        failures.append(f"an unknown loot table was not refused: it gave {got}")
    if unknown.get("ok", True) and not any(
            marker in line
            for line in unknown.get("chat", [])
            for marker in ("nknown", "an't find", "ailed", "rror", "loot_table")):
        failures.append(f"an unknown loot table answered without a refusal: {unknown}")
    if failures:
        game("close")
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(f"loot PASS: {len(names)}/{len(names)} carried loot tables each give exactly one of "
          f"their own block, and an unknown table is refused", flush=True)
    game("close")


if __name__ == "__main__":
    main()
