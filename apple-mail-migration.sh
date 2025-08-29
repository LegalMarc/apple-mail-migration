#!/bin/zsh
set -euo pipefail

# 1) Edit this to the new Mac’s login and IP or hostname
DEST="mhm@192.168.10.133"

# 2) SSH command as an ARRAY (works in zsh)
typeset -a SSH_OPTS
SSH_OPTS=(ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=120 -o TCPKeepAlive=yes -C)

# 3) For rsync’s -e, pass a single string
RSYNC_E="${SSH_OPTS[*]}"

# 4) Resumable, safe flags for Apple’s built-in rsync
FLAGS=(-a --partial --inplace --progress
       --exclude '*/._*' --exclude '.DS_Store' --delete
       -e "$RSYNC_E")

echo "Keeping this Mac awake…"
caffeinate -dimsu >/dev/null 2>&1 &

echo "Checking destination connectivity…"
"${SSH_OPTS[@]}" "$DEST" 'echo "OK: connected to $(hostname)"; whoami; df -h ~'

echo "Quitting Mail on both Macs and prepping destination…"
osascript -e 'tell application "Mail" to quit' || true
pkill -x Mail || true
"${SSH_OPTS[@]}" "$DEST" '
  osascript -e "tell application \"Mail\" to quit" || true; pkill -x Mail || true;
  mkdir -p ~/Library/"Mail Downloads" ~/Library/Containers ~/Library/"Group Containers" \
           ~/Library/Preferences ~/Library/"Saved Application State" ~/Library/Mail;
  caffeinate -dimsu >/dev/null 2>&1 &
'

echo "Pushing Mail store…"
rsync "${FLAGS[@]}" "$HOME/Library/Mail/"                                      "$DEST:Library/Mail/"

echo "Pushing attachments folder (if present)…"
rsync "${FLAGS[@]}" "$HOME/Library/Mail Downloads/"                            "$DEST:Library/" 2>/dev/null || true

echo "Pushing Mail containers…"
rsync "${FLAGS[@]}" "$HOME/Library/Containers/com.apple.mail/"                 "$DEST:Library/Containers/"
rsync "${FLAGS[@]}" "$HOME/Library/Containers/com.apple.MailServiceAgent/"     "$DEST:Library/Containers/"

echo "Pushing group container (if present)…"
rsync "${FLAGS[@]}" "$HOME/Library/Group Containers/group.com.apple.mail/"     "$DEST:Library/Group\ Containers/" 2>/dev/null || true

echo "Pushing preferences (if present)…"
rsync "${FLAGS[@]}" "$HOME/Library/Preferences/com.apple.mail.plist"           "$DEST:Library/Preferences/" 2>/dev/null || true
rsync "${FLAGS[@]}" "$HOME/Library/Preferences/com.apple.mail-shared.plist"    "$DEST:Library/Preferences/" 2>/dev/null || true

echo "Pushing saved window state (if present)…"
rsync "${FLAGS[@]}" "$HOME/Library/Saved Application State/com.apple.mail.savedState/" \
                                                         "$DEST:Library/Saved\ Application\ State/" 2>/dev/null || true

echo "Done. If the connection drops, re-run this script; rsync will resume."