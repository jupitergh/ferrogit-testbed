#!/usr/bin/env bash
# Rebuild the uncommitted state that a clone cannot carry.
#
# `git clone` brings commits, branches and tags. It does NOT bring the working tree's
# modifications, its untracked files, or the stash — and for a git GUI's testbed those are not
# incidental, they are most of what there is to look at: the three file lists, the
# uncommitted-changes row, the staging paths and the stash list are all empty without them.
#
# Run this once after cloning:
#
#     git clone git@github.com:jupitergh/ferrogit-testbed.git
#     cd ferrogit-testbed && ./setup-working-state.sh
#
# It is idempotent: it resets to a clean tree first, so running it twice is the same as once.
#
# Every fixture below is deliberate. If you change one, say here what it is for, because the
# thing being tested is usually invisible from the file's contents.

set -euo pipefail
cd "$(dirname "$0")"

# ⚠️ **Commit any edit to THIS script before running it.** The reset below restores every tracked
# file to `HEAD`, and this script is tracked, so an uncommitted change to it is discarded and the
# *previous* version is what runs. That reads as the edit having no effect, which cost a debugging
# cycle when the stash fix below appeared not to work.
if [ -n "$(git status --porcelain)" ]; then
    echo "resetting to a clean tree first"
    git checkout -- . 2>/dev/null || true
    git clean -fd 2>/dev/null || true
fi

# `git stash clear`, and NOT `while git stash list | grep -q .; do git stash drop; done`.
# Under `set -o pipefail` that loop is a race that silently does nothing: `grep -q` exits on the
# first line, `git stash list` takes SIGPIPE and exits 141, pipefail promotes that to the
# pipeline's status, and the `while` condition reads false. It only fires once the list is long
# enough not to fit the pipe buffer -- so it "works" when tested with three stashes and stops
# working later, which is how this script first ran twice and left six.
git stash clear

# Three stashes, so the sidebar's stash section has more than one row and their order is visible.
# They differ only in the trailing comment, which makes "did the right stash apply?" checkable.
for n in 1 2 3; do
    printf '\n// stashed experiment %s\n' "$n" >> src/runtime.rs
    git stash push --quiet -m "experiment $n: not ready"
done

# A tracked CRLF file rewritten with LF endings and one changed line.
#
# This is the `core.autocrlf` trap: on a Windows checkout the object database holds LF while the
# working tree holds CRLF, so a diff that does not decide explicitly what it is comparing reports
# EVERY line of the file as modified. One line here genuinely changed; the other two changed only
# in their line ending. A correct diff shows one row, not three.
printf 'line one\nline two changed\nline three\n' > docs/windows-endings.txt

# A modified file whose path is not ASCII, so the file lists, the diff header and the status bar
# are all exercised on a path that needs real UTF-8 handling rather than byte slicing.
#
# ⚠️ This deliberately does NOT recreate the untracked NFD twin of this path that the original
# working tree carried. On a normalisation-insensitive volume -- APFS and HFS+, so every default
# macOS checkout -- the NFC and NFD spellings are the SAME FILE: measured here, writing the NFD
# name landed on the NFC file's inode and `ls` reported one entry, not two. A script that claims
# to create it silently overwrites the tracked file instead, which is worse than not having the
# fixture at all, because the tree then looks clean while the fixture is gone. NFC-vs-NFD needs a
# normalisation-sensitive filesystem (ext4) to exist; that is a Linux-only fixture and belongs in
# a test that can state its requirement, not in a setup script that cannot check it.
printf 'coste: 100%% — café, año, mañana, y una línea sin commitear\n' \
    > "$(printf 'docs/\xc3\xa1ccented-\xc3\xb1ame.txt')"

printf 'scratch notes, untracked\n' > NOTES.md

echo
echo "working state rebuilt:"
git status --short
echo
git stash list
