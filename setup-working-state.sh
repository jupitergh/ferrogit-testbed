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

if [ -n "$(git status --porcelain)" ]; then
    echo "resetting to a clean tree first"
    git checkout -- . 2>/dev/null || true
    git clean -fd 2>/dev/null || true
fi
while git stash list | grep -q .; do git stash drop >/dev/null; done

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

# An untracked file whose name is the NFD form of a tracked file's NFC name.
#
# macOS normalises filenames to NFD on disk while git stores the bytes it was given, so these two
# are one file to the filesystem and two paths to git. It is the case that makes "is this path
# already tracked?" a real question rather than a string comparison.
printf 'coste: 100%% — café, año, mañana\n' > "$(printf 'docs/a\xcc\x81ccented-n\xcc\x83ame.txt')"

printf 'scratch notes, untracked\n' > NOTES.md

echo
echo "working state rebuilt:"
git status --short
echo
git stash list
