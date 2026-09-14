#!/usr/bin/env bash
# Copy the H11V game to the PocketTerm35 and start it.
#
#   tools/deploy_to_term35.sh                 copy the game + mid profile, start it
#   tools/deploy_to_term35.sh --profile=low   pick the graphics profile (low|mid|high)
#   tools/deploy_to_term35.sh --fresh         delete the device world first
#   tools/deploy_to_term35.sh --uncapped      lift fps_max (for measuring only)
#   tools/deploy_to_term35.sh --trees=0.004   thin the forest (implies --fresh)
#   tools/deploy_to_term35.sh --no-run        copy only, do not start
#   tools/deploy_to_term35.sh --stop          stop whatever is running on the device
#   tools/deploy_to_term35.sh --log           tail the game log on the device
#   tools/deploy_to_term35.sh --setup-key     install an ssh key (asked once, then
#                                             every deploy runs without a password)
#
# Connection details are read at run time from .term35-connect.txt in the repo
# root ("ip:", "user:", "psswd:", one per line). That file is gitignored on purpose,
# and the password is never hardcoded, echoed, logged, or put in any process's argv.
#
# Unlike the Godot sibling project there is no binary to export: Luanti is
# installed on the device as a package and H11V is content. What ships is the
# game directory plus one assembled minetest.conf (shared base + the chosen
# profile's deltas), so a profile switch is a redeploy, not an edit on the device.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONN_FILE="${TERM35_CONN_FILE:-$ROOT/.term35-connect.txt}"
GAME_SRC="$ROOT/games/h11v"
REMOTE_DIR="h11v"
PROFILE="mid"

do_run=1 setup_key=0 stop_only=0 log_only=0 fresh=0 uncapped=0 trees=""
for arg in "$@"; do
	case "$arg" in
		--profile=*) PROFILE="${arg#*=}" ;;
		--fresh) fresh=1 ;;
		--uncapped) uncapped=1 ;;
		--trees=*) trees="${arg#*=}"; fresh=1 ;;
		--no-run) do_run=0 ;;
		--setup-key) setup_key=1 ;;
		--stop) stop_only=1 ;;
		--log) log_only=1 ;;
		-h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
	esac
done

die() { echo "error: $*" >&2; exit 1; }

case "$PROFILE" in low|mid|high) ;; *) die "unknown profile '$PROFILE' (low|mid|high)" ;; esac

# --- credentials -------------------------------------------------------------

[ -f "$CONN_FILE" ] || die "no credentials file at $CONN_FILE
Create it with at least:
  ip: 192.168.1.105
  user: ich
  psswd: <device password>"

# Reads "key: value" from the credentials file. Tolerates spaces and CRLF.
cfg_get() {
	sed -n "s/^[[:space:]]*$1[[:space:]]*:[[:space:]]*//p" "$CONN_FILE" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}

IP="$(cfg_get ip)"
DEV_USER="$(cfg_get user)"
DEV_PASS="$(cfg_get psswd)"
[ -n "$IP" ] || die "no 'ip:' line in $CONN_FILE"
[ -n "$DEV_USER" ] || die "no 'user:' line in $CONN_FILE"
TARGET="$DEV_USER@$IP"

# --- ssh transport -----------------------------------------------------------

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

# When a password is unavoidable it reaches sshpass through the environment, with
# `sshpass -e`, and never through its `-p <password>` flag, which puts the password
# into a command line. (Spelled that way so a grep for the forbidden form finds no
# hits at all, including this explanation of it.)
#
# rsync is why that distinction is a security defect and not a matter of taste:
# RSYNC_RSH is handed to rsync as its own `-e` argument, and rsync does not mask its
# argv — so for the whole multi-second transfer `ps aux` on this Mac showed the
# device password in clear text to every other account on the machine (v0.8 review
# H1; the bare ssh/scp/ssh-copy-id calls leaked the same value for the shorter life
# of each process). `-e` also removes a second, quieter defect in the same line: the
# password was interpolated *unquoted* into that string, and rsync word-splits `-e`
# itself, so a password containing a space was silently truncated and its remainder
# became a remote command word — an auth failure with no plausible cause.
#
# Do not "simplify" this back to -p. And note what holds it: SSHPASS has exactly one
# assignment in this file and is never echoed, never logged, and never traced —
# there is no `set -x` here and there must not be one.
sshpass_from_env() {
	export SSHPASS="$DEV_PASS"
}

key_auth_works() {
	ssh -o BatchMode=yes "${SSH_OPTS[@]}" "$TARGET" true 2>/dev/null
}

## Tell "the device is switched off" apart from "the key is not installed".
## Without this every unreachable host looks like an auth failure.
reachable() {
	if command -v nc >/dev/null 2>&1; then
		nc -z -G 5 "$IP" 22 >/dev/null 2>&1
	else
		(exec 3<>"/dev/tcp/$IP/22") >/dev/null 2>&1
	fi
}

reachable || die "no answer from $IP on port 22.
The PocketTerm is powered off, asleep, or on a different network.
Check it is on and reachable, then run this again."

if [ "$setup_key" = 1 ]; then
	[ -f "$HOME/.ssh/id_ed25519.pub" ] || [ -f "$HOME/.ssh/id_rsa.pub" ] || {
		echo "==> no ssh key yet, generating one"
		ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
	}
	echo "==> installing your public key on $TARGET"
	if command -v sshpass >/dev/null 2>&1 && [ -n "$DEV_PASS" ]; then
		sshpass_from_env
		sshpass -e ssh-copy-id "${SSH_OPTS[@]}" "$TARGET"
	else
		echo "    (the password is the 'psswd:' line in $CONN_FILE)"
		ssh-copy-id "${SSH_OPTS[@]}" "$TARGET"
	fi
	key_auth_works && echo "==> key auth works, deploys need no password now" \
		|| die "key installed but key auth still fails"
	exit 0
fi

SSH=(ssh "${SSH_OPTS[@]}")
RSYNC_RSH="ssh ${SSH_OPTS[*]}"
SCP=(scp "${SSH_OPTS[@]}")
if key_auth_works; then
	:
elif command -v sshpass >/dev/null 2>&1 && [ -n "$DEV_PASS" ]; then
	# Password from the credentials file, handed over in the environment - see
	# sshpass_from_env above for why it is -e and must stay -e. RSYNC_RSH stays a
	# single string because rsync tokenizes `-e` on whitespace itself; every token
	# in it is space-free by construction, which is exactly what the old form could
	# not promise once the password was inside it.
	sshpass_from_env
	SSH=(sshpass -e "${SSH[@]}")
	SCP=(sshpass -e "${SCP[@]}")
	RSYNC_RSH="sshpass -e $RSYNC_RSH"
else
	cat >&2 <<EOF
error: cannot log in to $TARGET without typing a password every time.

Fix it once with:
    tools/deploy_to_term35.sh --setup-key

(or install sshpass: brew install hudochenkov/sshpass/sshpass)
EOF
	exit 1
fi

# Luanti is the process name on a Debian package install; older builds are
# "minetest". Stop and probe both rather than guessing which one is there.
PKILL='pkill -x luanti || pkill -x minetest || true'
PGREP='pgrep -x luanti >/dev/null || pgrep -x minetest >/dev/null'

# --- one-off actions ---------------------------------------------------------

if [ "$stop_only" = 1 ]; then
	# Wait for it to actually be gone before saying so. pkill returns as soon as
	# the signal is delivered, and the game takes a moment to exit — so a bare
	# "==> stopped" is a claim about a signal, not about the device. Anything
	# scripted after a stop (a redeploy, a measurement) would race it.
	#
	# Both probes now use $PGREP, which asks about both process names. The one after
	# the SIGKILL asked about "luanti" alone, so a stuck pre-rename "minetest" binary
	# — the very case the kill above it handles — made this print "==> stopped" and
	# exit 0 with the engine still running, handing the false all-clear to whatever
	# was scripted next (v0.8 review L13). It also polls to a deadline instead of
	# sleeping 0.5 s once: SIGKILL is immediate, reaping a process blocked in
	# uninterruptible I/O is not.
	"${SSH[@]}" "$TARGET" "
		$PKILL
		for _ in 1 2 3 4 5 6 7 8 9 10; do
			$PGREP || exit 0
			sleep 0.5
		done
		pkill -9 -x luanti 2>/dev/null; pkill -9 -x minetest 2>/dev/null
		for _ in 1 2 3 4 5 6; do
			$PGREP || exit 0
			sleep 0.5
		done
		exit 1
	" && echo "==> stopped" || { echo "==> still running after SIGKILL" >&2; exit 1; }
	exit 0
fi

if [ "$log_only" = 1 ]; then
	exec "${SSH[@]}" "$TARGET" "tail -f ~/$REMOTE_DIR/h11v.log"
fi

# --- preconditions -----------------------------------------------------------

[ -d "$GAME_SRC" ] || die "no game at $GAME_SRC
The game tree does not exist yet. See specification/ROADMAP.md v0.1."
[ -f "$ROOT/tools/device/minetest.conf" ] || die "no tools/device/minetest.conf"
[ -f "$ROOT/tools/device/device-$PROFILE.conf" ] || die "no tools/device/device-$PROFILE.conf"

"${SSH[@]}" "$TARGET" "command -v luanti >/dev/null 2>&1 || command -v minetest >/dev/null 2>&1" \
	|| die "neither 'luanti' nor 'minetest' is on PATH on the device.
Install it there first (apt install luanti), then deploy."

# --- assemble the config -----------------------------------------------------

# Base plus the profile's deltas, in that order, so a later key wins. Built here
# rather than on the device: the device gets one file and no logic.
# `mktemp -t PREFIX` is a BSD-ism: GNU mktemp reads -t as the deprecated "template
# in $TMPDIR" flag and refuses a template with no XXXXXX, so this line aborted the
# deploy on any GNU box (v0.8 review L17 — the same Mac-ism the worldgen gate hit at
# M13). The explicit template works on both.
CONF_TMP="$(mktemp "${TMPDIR:-/tmp}/h11v-conf.XXXXXX")"
trap 'rm -f "$CONF_TMP"' EXIT
{
	echo "# Generated by tools/deploy_to_term35.sh - do not edit on the device."
	echo "# base: tools/device/minetest.conf   profile: device-$PROFILE.conf"
	cat "$ROOT/tools/device/minetest.conf"
	echo
	cat "$ROOT/tools/device/device-$PROFILE.conf"
	echo
	echo "# Blanks the on-screen jump/sneak buttons - see tools/device/texturepack/"
	echo "texture_path = /home/$DEV_USER/$REMOTE_DIR/texturepack"
	# Device-only: the gamepad buttons take W/A/S/D away, which the Mac needs.
	echo
	cat "$ROOT/tools/device/gamepad.conf"
	# Measuring a profile against its own fps_max measures the fps_max. Appended
	# last so it wins, and only when asked for: the cap is a real shipping choice
	# and must not be lost by accident.
	if [ "$uncapped" = 1 ]; then
		echo
		echo "# --uncapped: measurement only, not a shipping value"
		echo "fps_max = 250"
	fi
	# Decorations are placed at generation, so this only takes effect on a world
	# that does not exist yet — hence --trees implying --fresh.
	if [ -n "$trees" ]; then
		echo
		echo "# --trees: inspection only, not a shipping value"
		echo "h11v_tree_density = $trees"
	fi
} > "$CONF_TMP"

# --- copy --------------------------------------------------------------------

echo "==> deploying game + '$PROFILE' profile to $TARGET:~/$REMOTE_DIR/"
"${SSH[@]}" "$TARGET" "mkdir -p ~/$REMOTE_DIR"

# Stage everything under .incoming and swap at the end. A dropped connection or a
# full disk then leaves the device with its previous, working game rather than a
# half-written one - the state it cannot recover from on its own.
if command -v rsync >/dev/null 2>&1; then
	rsync -a --delete -e "$RSYNC_RSH" \
		--exclude '.DS_Store' --exclude '.git' \
		"$GAME_SRC/" "$TARGET:~/$REMOTE_DIR/game.incoming/"
else
	"${SSH[@]}" "$TARGET" "rm -rf ~/$REMOTE_DIR/game.incoming"
	"${SCP[@]}" -r "$GAME_SRC" "$TARGET:~/$REMOTE_DIR/game.incoming"
fi
"${SCP[@]}" "$CONF_TMP" "$TARGET:~/$REMOTE_DIR/minetest.conf.incoming" || die "config copy failed; the device still has its previous deploy"
"${SCP[@]}" "$ROOT/tools/run_on_pi.sh" "$TARGET:~/$REMOTE_DIR/run_on_pi.sh.incoming" || die "run_on_pi.sh copy failed; nothing on the device was swapped"
# The texture pack blanks two engine buttons the layout cannot move in 5.10.
if command -v rsync >/dev/null 2>&1; then
	rsync -a --delete -e "$RSYNC_RSH" "$ROOT/tools/device/texturepack/" "$TARGET:~/$REMOTE_DIR/texturepack/" || die "texture pack copy failed"
else
	"${SSH[@]}" "$TARGET" "rm -rf ~/$REMOTE_DIR/texturepack"
	"${SCP[@]}" -r "$ROOT/tools/device/texturepack" "$TARGET:~/$REMOTE_DIR/texturepack"
fi

# Everything arrived. Stop the game and swap - mv within one filesystem is atomic.
#
# WAIT for it to be gone, do not just signal it. Luanti writes its settings back
# to the config file as it shuts down, so a deploy that swaps the file while the
# old process is still dying gets its new config overwritten by the old one's
# memory — silently, and with the comments preserved so it looks like it worked.
# That cost an afternoon: a whole keymap block arrived as comments with every
# setting stripped out. Same lesson as --stop, which learned it first — and only
# half-learned here, because this path signalled, slept 0.5 s and then swapped
# unconditionally. On a slow SD card an engine blocked in uninterruptible I/O can
# outlive that grace period and complete its write-back AFTER the swap, which is
# precisely the clobber the wait exists to prevent (v0.8 review M7; docs/decisions.md,
# 2026-09-13, "A deploy must wait for the engine to exit, not just signal it").
#
# So the SIGKILL is verified the way --stop verifies it, and a survivor stops the
# deploy here, before the mv. A deploy that refuses is recoverable by running it
# again; a config overwritten by a dying engine looks deployed and is not.
"${SSH[@]}" "$TARGET" "
	$PKILL
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		$PGREP || exit 0
		sleep 0.5
	done
	pkill -9 -x luanti 2>/dev/null; pkill -9 -x minetest 2>/dev/null
	for _ in 1 2 3 4 5 6; do
		$PGREP || exit 0
		sleep 0.5
	done
	exit 1" || die "the engine on $TARGET survived the SIGKILL, so nothing was swapped.
Luanti writes its settings back to the config file as it shuts down, so swapping now
would let the dying process overwrite this deploy silently. Everything staged is
still safe in ~/$REMOTE_DIR/*.incoming.
Find out what is holding it (ps, and dmesg for SD-card I/O errors), then run this
deploy again - it will re-stage and swap."
"${SSH[@]}" "$TARGET" "
	set -e
	cd ~/$REMOTE_DIR
	rm -rf game && mv game.incoming game
	mv minetest.conf.incoming minetest.conf
	mv run_on_pi.sh.incoming run_on_pi.sh && chmod +x run_on_pi.sh
"

# Chunks are persisted, so a world generated before a mapgen change keeps showing
# the old terrain — and a deploy that silently shows stale geometry is how a fixed
# mapgen gets reported as still broken. v0.7's fixed-seed protocol needs this too.
if [ "$fresh" = 1 ]; then
	"${SSH[@]}" "$TARGET" 'rm -rf ~/.luanti/worlds/h11v_dev ~/.minetest/worlds/h11v_dev'
	echo "==> removed the device world; it will regenerate"
fi

# The Sway desktop entry. v0's outcome is that the game "launches fullscreen from
# the Sway desktop", not only from this script — so the launcher is part of the
# deploy rather than something set up by hand once and lost on the next reflash.
# wofi --show drun reads ~/.local/share/applications directly, so no database
# refresh is needed.
"${SSH[@]}" "$TARGET" "mkdir -p ~/.local/share/applications"
sed "s|@REMOTE@|/home/$DEV_USER/$REMOTE_DIR|g" "$ROOT/tools/device/h11v.desktop" \
	| "${SSH[@]}" "$TARGET" "cat > ~/.local/share/applications/h11v.desktop"

if [ "$do_run" = 0 ]; then
	echo "==> copied. Start it on the device with:  ~/$REMOTE_DIR/run_on_pi.sh"
	exit 0
fi

# --- run ---------------------------------------------------------------------

echo "==> starting H11V on the device"
# Three details, all learned the hard way in the sibling project:
#  * setsid, not just nohup - the game must leave this ssh session's process
#    group, or it dies the moment the connection closes.
#  * ssh -f - a surviving process keeps the ssh channel's fds open, so a normal
#    ssh call would hang forever waiting for EOF instead of returning.
#  * the trailing "&" plus >/dev/null - otherwise the backgrounded ssh keeps this
#    script's own stdout open and any pipeline around it never ends.
"${SSH[@]}" -f "$TARGET" "cd ~/$REMOTE_DIR && setsid ./run_on_pi.sh >h11v.log 2>&1 </dev/null &" >/dev/null 2>&1

# Separate connection: proves the game outlived the one that spawned it.
sleep 5
if "${SSH[@]}" "$TARGET" "$PGREP" 2>/dev/null; then
	echo "==> running"
else
	echo "the game did not stay up, last log lines:" >&2
	"${SSH[@]}" "$TARGET" "tail -20 ~/$REMOTE_DIR/h11v.log" >&2 || true
	exit 1
fi

# The GPU preflight from specification/ARCHITECTURE.md: an llvmpipe fallback
# renders correctly and makes every fps number fiction, so it must be loud.
# tools/gpu_preflight.sh is the authoritative probe, but it asks glxinfo — a
# different process; this is the confirmation from the engine's own log, which is
# the renderer the ENGINE was given.
#
# Three things about the shape of this, all of them repairs to a block that could
# not fire (v0.8 review M4):
#
#  * It greps for the GPU name itself — llvmpipe/softpipe/swrast, or V3D — not for
#    the word "renderer". The line that carries it is the Irrlicht driver-init dump,
#    whose wording belongs to the engine and is not ours to depend on.
#  * It needs debug_log_level = info, which tools/device/minetest.conf now sets. At
#    the engine's default level the log holds no driver lines at all, so the grep
#    matched nothing on every run and skipped in silence — while the comment above it
#    told the reader the renderer actually used had been confirmed. That is the worst
#    of the three states: no evidence, presented as evidence.
#  * One log, not four. h11v-debug.txt is the --logfile run_on_pi.sh truncates at
#    every launch, so it describes THIS run. ~/.minetest/debug.txt and
#    ~/.luanti/debug.txt were also searched and are appended to forever, so a line
#    from a launch three deploys ago could be reported as today's renderer; h11v.log
#    is only run_on_pi.sh's stdout, and the console stream stays at action level.
#
# Polled rather than read once: pgrep has proved the engine is alive, but on a slow
# SD card the driver may still be initialising, and an empty grep one second too
# early is indistinguishable from a renderer that never logged.
GPU_EVIDENCE="$("${SSH[@]}" "$TARGET" "
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		hit=\$(grep -ihE -m1 'llvmpipe|softpipe|swrast|v3d' ~/$REMOTE_DIR/h11v-debug.txt 2>/dev/null)
		[ -n \"\$hit\" ] && { printf '%s\n' \"\$hit\"; exit 0; }
		sleep 1
	done" 2>/dev/null || true)"
# Matched case-insensitively above, so fold the answer before classifying it.
case "$(printf '%s' "$GPU_EVIDENCE" | tr '[:upper:]' '[:lower:]')" in
	*llvmpipe*|*softpipe*|*swrast*)
		echo "==> renderer (engine log): $GPU_EVIDENCE"
		echo "WARNING: software rasterizer in use - fps measurements from this run are void." >&2
		echo "         Fix GLX/V3D on the device before measuring (ARCHITECTURE.md, GPU path)" >&2
		echo "         and re-run tools/gpu_preflight.sh." >&2 ;;
	*v3d*)
		echo "==> renderer (engine log): $GPU_EVIDENCE" ;;
	*)
		# Loud, because the alternative is the defect this block was just repaired
		# from: a missing check that reads as a passed one.
		echo "NOTE: the engine log named no renderer, so this deploy has confirmed nothing." >&2
		echo "      Expected a driver line naming V3D in ~/$REMOTE_DIR/h11v-debug.txt." >&2
		echo "      Check that debug_log_level = info reached ~/$REMOTE_DIR/minetest.conf;" >&2
		echo "      until it does, treat the renderer as unverified and trust only" >&2
		echo "      tools/gpu_preflight.sh." >&2 ;;
esac

echo "==> done.  logs: tools/deploy_to_term35.sh --log   stop: tools/deploy_to_term35.sh --stop"
