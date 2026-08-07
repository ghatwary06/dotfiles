#!/usr/bin/env bash
# Chat backend for the side panel — a real Claude Code agent, tools and all.
#
# NO API KEY IS INVOLVED. This reuses the Claude Code login already on this
# machine, so a turn costs exactly what a turn in the terminal costs.
#
# Usage:  chat.sh <session_id|-> <prompt>
#
# The prompt is a normal argv element, never interpolated into a command string.
# Quickshell's Process execs directly with no shell in between, so quotes, $,
# backticks and newlines in a chat message are inert data the whole way down.
# (Verified with a prompt containing $(whoami), backticks and ";rm -rf /" — it
# came back verbatim and unexpanded.)

set -uo pipefail

SESSION=${1:--}
PROMPT=${2:-}
[[ $SESSION == "-" ]] && SESSION=""

[[ -z $PROMPT ]] && {
    echo '{"type":"result","subtype":"error","result":"empty prompt"}'
    exit 2
}

# Run from $HOME so relative paths in a question ("read .config/hypr/rice.lua")
# resolve the way they would in a normal terminal session.
cd "$HOME" 2> /dev/null || true

# --- permissions -------------------------------------------------------------
# "auto" is the only mode that makes an agent usable from a surface with no way
# to draw an approval dialog. The alternatives all fail here:
#   manual            -> blocks waiting for an approval the panel cannot render,
#                        so the reply hangs forever
#   bypassPermissions -> runs anything at all, no classifier, no backstop
#   plan              -> read-only, never acts
# "auto" runs the safe majority outright and lets the classifier refuse the
# dangerous minority by itself, reporting the refusal as ordinary text.
PERM=auto

# Only two tools are denied, and neither for safety:
#   AskUserQuestion  would block on a dialog the panel cannot draw
#   EndConversation  is meaningless for a panel session
# Everything else — Bash, Edit, Write, Read, WebFetch, Agent — is available,
# exactly as in the terminal.
DENY=(AskUserQuestion EndConversation)

args=(-p
      --output-format stream-json
      --verbose
      --include-partial-messages
      --permission-mode "$PERM"
      --disallowed-tools "${DENY[@]}")

# MCP servers stay OFF — the one deliberate difference from the terminal.
# The connectors reach OUTSIDE this machine (Composio's remote bash, Google
# Drive), and a desktop quick-question box is not where that reach belongs.
# Delete this line to get them back.
args+=(--strict-mcp-config)

# Resume keeps the thread going across turns. Without it every message would be
# a fresh conversation with no memory of the last one.
[[ -n $SESSION ]] && args+=(--resume "$SESSION")

exec claude "${args[@]}" -- "$PROMPT"
