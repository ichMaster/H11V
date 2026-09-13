#!/usr/bin/env bash
# Copy the H11V game to the PocketTerm35 and start it.
#
#   tools/deploy_to_term35.sh                 copy the game + mid profile, start it
#   tools/deploy_to_term35.sh --profile=low   pick the graphics profile (low|mid|high)
#   tools/deploy_to_term35.sh --fresh         delete the device world first
#   tools/deploy_to_term35.sh --uncapped      lift fps_max (for measuring only)
#   tools/deploy_to_term35.sh --no-run        copy only, do not start
#   tools/deploy_to_term35.sh --stop          stop whatever is running on the device
#   tools/deploy_to_term35.sh --log           tail the game log on the device
#   tools/deploy_to_term35.sh --setup-key     install an ssh key (asked once, then
#                                             every deploy runs without a password)
#
# Connection details are read at run time from .term35-connect.txt in the repo
# root ("ip:", "user:", "psswd:", one per line). That file is gitignored on
# purpose: nothing here hardcodes, echoes or logs the password.
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

do_run=1 setup_key=0 stop_only=0 log_only=0 fresh=0 uncapped=0
for arg in "$@"; do
	case "$arg" in
		--profile=*) PROFILE="${arg#*=}" ;;
		--fresh) fresh=1 ;;
		--uncapped) uncapped=1 ;;
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
		sshpass -p "$DEV_PASS" ssh-copy-id "${SSH_OPTS[@]}" "$TARGET"
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
	# Password from the credentials file; never printed, never in the argv of ssh.
	SSH=(sshpass -p "$DEV_PASS" "${SSH[@]}")
	SCP=(sshpass -p "$DEV_PASS" "${SCP[@]}")
	RSYNC_RSH="sshpass -p $DEV_PASS $RSYNC_RSH"
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
	"${SSH[@]}" "$TARGET" "
		$PKILL
		for _ in 1 2 3 4 5 6 7 8 9 10; do
			pgrep -x luanti >/dev/null 2>&1 || pgrep -x minetest >/dev/null 2>&1 || exit 0
			sleep 0.5
		done
		pkill -9 -x luanti 2>/dev/null; pkill -9 -x minetest 2>/dev/null
		sleep 0.5
		pgrep -x luanti >/dev/null 2>&1 && exit 1
		exit 0
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
CONF_TMP="$(mktemp -t h11v-conf)"
trap 'rm -f "$CONF_TMP"' EXIT
{
	echo "# Generated by tools/deploy_to_term35.sh - do not edit on the device."
	echo "# base: tools/device/minetest.conf   profile: device-$PROFILE.conf"
	cat "$ROOT/tools/device/minetest.conf"
	echo
	cat "$ROOT/tools/device/device-$PROFILE.conf"
	# Measuring a profile against its own fps_max measures the fps_max. Appended
	# last so it wins, and only when asked for: the cap is a real shipping choice
	# and must not be lost by accident.
	if [ "$uncapped" = 1 ]; then
		echo
		echo "# --uncapped: measurement only, not a shipping value"
		echo "fps_max = 250"
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

# Everything arrived. Stop the game and swap - mv within one filesystem is atomic.
"${SSH[@]}" "$TARGET" "$PKILL"
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
# tools/gpu_preflight.sh is the authoritative probe; this is the post-launch
# confirmation from the engine's own log, which is the renderer actually used.
# h11v-debug.txt is the engine log run_on_pi.sh writes with --logfile; h11v.log is
# only that script's stdout and carries no renderer line. The other two are
# fallbacks for a device someone configured by hand.
RENDERER="$("${SSH[@]}" "$TARGET" "grep -ihm1 -e 'renderer' ~/$REMOTE_DIR/h11v-debug.txt ~/$REMOTE_DIR/h11v.log ~/.minetest/debug.txt ~/.luanti/debug.txt 2>/dev/null" || true)"
if [ -n "$RENDERER" ]; then
	echo "==> renderer: $RENDERER"
	case "$RENDERER" in
		*llvmpipe*|*softpipe*|*swrast*)
			echo "WARNING: software rasterizer in use - fps measurements from this run are void." >&2
			echo "         Fix EGL/V3D on the device before measuring (ARCHITECTURE.md, GPU path)." >&2 ;;
	esac
fi

echo "==> done.  logs: tools/deploy_to_term35.sh --log   stop: tools/deploy_to_term35.sh --stop"
