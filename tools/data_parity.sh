#!/usr/bin/env bash
# Carried-data parity for Simply Light (content-only 0.2.x), at the 0a875da pin.
#
# Default run (one launch, The End, creative):
#   1. gap 6 of notes.md — "fluid behaviour was not exercised": water is placed
#      in the cell and the block is placed INTO it, for the eight waterlogged
#      families (panel, slab, wall lamp, light bulb, rod lamp, lamp post, both
#      edge lights). Each must read `waterlogged=true`. The differential is the
#      same placement in air (`waterlogged=false`) and a stateless block
#      (`illuminant_block`) placed into water, which has no `waterlogged` at all;
#   2. all 234 carried recipes are crafted in a real crafting table by
#      tools/data_parity.py (declared result id + count, ingredients consumed,
#      output in the inventory), and all 160 carried loot tables are rolled
#      (each gives exactly one of its own block; an unknown table is refused).
#
#   GAME=~/.cache/horizon-e2e/0a875da/control/horizon-client \
#   CTL=~/.cache/horizon-e2e/0a875da/control/horizon-ctl \
#   RES=~/.cache/horizon-e2e/root/data/horizon-launcher/versions/nightly-2026-11-20-0a875da/.local/horizon-client/26.3 \
#   tools/data_parity.sh
#
# SELFTEST=1 asserts a deliberately wrong expectation for the first waterlogged
# family (the panel must read `waterlogged=false`), so the run MUST exit 1.
# SELFTEST=recipe does the same inside the recipe sweep (one extra crafted item),
# so it too MUST exit 1: the assertions are live.
# NEGATIVE=1 launches the same world WITHOUT `--dev-mod` and asserts the carried
# data is absent there, so the run MUST exit 1: the parity above is the
# package's, not the engine's. Every leg prints `EXIT:<status>` last.
set -euo pipefail

CLONE=/home/adlf/Desktop/all_the_mods_10_rust_rewrite
PORT=$CLONE/ports/simplylight
PKG=$PORT/simplylight.hmod
CTL=${CTL:-$HOME/.cache/horizon-e2e/0a875da/control/horizon-ctl}
GAME=${GAME:-}
RES=${RES:-${HORIZON_RES:-$HOME/.cache/horizon-e2e/root/data/horizon-launcher/versions/nightly-2026-11-20-0a875da/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/simplylight-parity.sock}
SELFTEST=${SELFTEST:-0}
NEGATIVE=${NEGATIVE:-0}

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -n "$GAME" ] || { echo "set GAME=<a horizon-client at the pin> (see the header)" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PKG" ] || { echo "missing package: $PKG" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/simplylight-parity.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
say() { echo "+ $*"; }
end() { ctl command "execute in minecraft:the_end run $1"; }
state_of() { ctl block "$1" "$2" "$3" | jq -r '.state // "unknown"'; }
state_has() { # state key value
    echo "$1" | grep -Eq "(^|[,\[)${2}=${3}([],]|$)" || fail "$1: expected $2=$3"
}

cleanup() {
    local status=$?
    echo "EXIT:$status"
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" || true
}
trap cleanup EXIT

say "launch (offscreen, creative, The End)"
if [ "$NEGATIVE" = 1 ]; then
    say "negative: the same world WITHOUT --dev-mod (the carried data must be absent)"
    ctl --socket "$SOCK" launch --game "$GAME" --world SimplyLightParityNegative \
        --seed 20261121 --creative --offscreen --wait --game-dir "$SCRATCH/game" \
        --resources "$RES"
else
    ctl --socket "$SOCK" launch --game "$GAME" --world SimplyLightParity \
        --seed 20261121 --creative --offscreen --wait --game-dir "$SCRATCH/game" \
        --resources "$RES" --dev-mod "$PKG"
fi
ctl wait-ready 240
end "forceload add -12 -12 340 12"
ctl wait 30
end "fill -12 99 -12 340 99 12 minecraft:stone"
end "kill @e[type=minecraft:item]"
end "kill @e[type=minecraft:ender_dragon]"
end "kill @e[type=minecraft:end_crystal]"
end "difficulty peaceful"
ctl wait 10
ctl close >/dev/null 2>&1 || true
ctl wait 3
end "tp @s 0.5 100 2.5"
ctl wait 5
say "platform: a stone floor at y=99"

if [ "$NEGATIVE" = 1 ]; then
    # The control leg: with no package the ids are air, the loot table is
    # unknown and the item cannot be given. The run MUST end non-zero.
    end "setblock 20 120 0 simplylight:illuminant_panel" >/dev/null 2>&1 || true
    ctl wait 2
    got=$(state_of 20 120 0)
    echo "without the package, setblock simplylight:illuminant_panel reads '$got'"
    if [ "$got" != "minecraft:air" ]; then
        fail "NEGATIVE run: the carried block exists without --dev-mod; the control is broken"
    fi
    loot=$(ctl command "loot give @s loot simplylight:blocks/illuminant_block")
    echo "without the package, /loot give simplylight:blocks/illuminant_block reads '$loot'"
    echo "$loot" | jq -r '.chat[]' | grep -q "Can't find element 'simplylight:blocks/illuminant_block'" \
        || fail "NEGATIVE run: the loot table exists without the package"
    if ctl give simplylight:illuminant_panel 1 >/dev/null 2>&1; then
        fail "NEGATIVE run: give simplylight:illuminant_panel succeeded without the package"
    fi
    echo "FAIL: NEGATIVE: the deliberately false assertion (the carried blocks, loot and items exist without --dev-mod) tripped, as it must; the --dev-mod differential is live (this exit 1 is the proof)" >&2
    exit 1
fi

# ---------------------------------------------------------- gap 6: waterlogging
# A stone cup round each target cell: below and the four horizontal neighbours
# are solid, so a facing family survives whichever face the placement clicks,
# and the open top lets the player place from above the water.
# A support block with the test cell above it and NO walls: a wall between the
# player and the support hides its top face from the click. The cells are 10
# blocks apart so a water source's spread cannot reach the next one (measured:
# a source at x does not even reach x+7 on this flat floor).
cup() { # x z water|air
    local x=$1 z=$2 cell=$3
    end "setblock $((x - 1)) 100 $z minecraft:air" >/dev/null
    end "setblock $((x + 1)) 100 $z minecraft:air" >/dev/null
    end "setblock $x 100 $((z - 1)) minecraft:air" >/dev/null
    end "setblock $x 100 $((z + 1)) minecraft:air" >/dev/null
    end "setblock $x 99 $z minecraft:stone" >/dev/null
    end "setblock $x 100 $z minecraft:$cell" >/dev/null
}

place_state() { # x z id -> echoes the read-back state
    local x=$1 z=$2 id=$3 state
    ctl command "tp @s $((x + 2)).5 100 $((z)).5" >/dev/null
    ctl wait 2 >/dev/null
    ctl command "clear @s" >/dev/null
    ctl give "$id" 1 >/dev/null
    ctl wait 2 >/dev/null
    ctl select "$id" >/dev/null
    ctl wait 1 >/dev/null
    # `place` refuses a cell that holds a fluid ("holds minecraft:water; break it
    # first"), and a waterlogged block is only ever made by placing INTO water, so
    # use the vanilla right-click path: click the top face of the stone below the
    # cell with the item held, exactly as a player does.
    local reply
    reply=$(ctl interact "$x" 99 "$z" up) || fail "cannot place $id at $x 100 $z: $reply"
    ctl wait 3 >/dev/null
    state=$(state_of "$x" 100 "$z")
    echo "$state" >&2
    echo "$state"
}

WATERLOGGED=(illuminant_panel illuminant_slab wall_lamp lightbulb rodlamp lamp_post edge_light edge_light_top)
say "gap 6: flowing water into the eight waterlogged families (The End, real placement)"
# x >= 20 clears the End exit-portal frame that the dragon kill leaves near (0,100,0).
X=20
for family in "${WATERLOGGED[@]}"; do
    id="simplylight:$family"
    cup "$X" 0 water
    echo -n "  water: $id -> "
    state=$(place_state "$X" 0 "$id")
    case "$state" in
        "$id"*) ;;
        *) fail "$id was not placed into water (read '$state')" ;;
    esac
    if [ "$SELFTEST" = 1 ] && [ "$family" = illuminant_panel ]; then
        # Deliberately wrong: the waterlogged panel must read false. It does not.
        echo "$state" | grep -q "waterlogged=true" \
            && { echo "FAIL: SELFTEST: the deliberately wrong waterlogged=false assertion tripped on '$state'; the fluid read-back is live (this exit 1 is the proof)" >&2; exit 1; }
        fail "SELFTEST: the deliberately wrong waterlogged=false assertion passed; the fluid read-back is vacuous"
    fi
    state_has "$state" waterlogged true
    X=$((X + 10))
done

say "the differential: the same placement in air is waterlogged=false"
for family in illuminant_panel rodlamp lamp_post edge_light; do
    id="simplylight:$family"
    cup "$X" 0 air
    echo -n "  air: $id -> "
    state=$(place_state "$X" 0 "$id")
    state_has "$state" waterlogged false
    X=$((X + 10))
done

say "the counterfactual: a stateless block placed into water has no waterlogged property"
cup "$X" 0 water
echo -n "  water: simplylight:illuminant_block -> "
state=$(place_state "$X" 0 "simplylight:illuminant_block")
case "$state" in
    simplylight:illuminant_block*) ;;
    *) fail "the stateless lamp was not placed into water (read '$state')" ;;
esac
if echo "$state" | grep -q "waterlogged"; then
    fail "simplylight:illuminant_block reports a waterlogged property: $state"
fi
echo "waterlogging PASS: 8/8 waterlogged families take the water at placement"
echo "(waterlogged=true), 4/4 read waterlogged=false in air, and the stateless"
echo "illuminant_block has no waterlogged property"

if [ "$SELFTEST" = recipe ]; then
    end "setblock 300 100 0 minecraft:crafting_table" >/dev/null
    ctl command "tp @s 300.5 100 1.5" >/dev/null
    ctl wait 5
    set +e
    PARITY_SELFTEST=1 python3 "$PORT/tools/data_parity.py" "$SOCK" "$CTL" "$PKG" "300,100,0"
    rc=$?
    set -e
    [ "$rc" -eq 1 ] || fail "SELFTEST: the deliberately wrong recipe expectation exited $rc, expected 1"
    echo "FAIL: SELFTEST: the deliberately wrong recipe expectation tripped on the first" \
         "carried recipe; the recipe assertion is live (this exit 1 is the proof)" >&2
    exit 1
fi

# ------------------------------------------------------- recipes + loot tables
say "recipes and loot tables (read from the delivered package)"
end "setblock 300 100 0 minecraft:crafting_table" >/dev/null
ctl command "tp @s 300.5 100 1.5" >/dev/null
ctl wait 5
ctl command "gamemode creative @s" >/dev/null
python3 "$PORT/tools/data_parity.py" "$SOCK" "$CTL" "$PKG" "300,100,0" \
    || fail "the carried-data parity sweep failed"

echo "PASS: 234/234 carried recipes craft their declared result id and count with the"
echo "ingredients consumed, 160/160 loot tables give exactly their own block and an"
echo "unknown table is refused, and the eight waterlogged families take water at placement"
