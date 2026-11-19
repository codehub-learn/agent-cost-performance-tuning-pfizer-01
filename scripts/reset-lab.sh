#!/usr/bin/env bash
# Put the lab back to a clean state between runs. Dry run by default: it lists what it would delete and deletes nothing.
#   scripts/reset-lab.sh            list what would be deleted
#   scripts/reset-lab.sh --yes      delete it
#   scripts/reset-lab.sh --yes --data    also delete the data/mockito clone (fetch-data brings it back)
# Deletes only: the files and folders in logs/ (not .gitkeep) and the work folder ../triage-work.
# It never touches ~/.copilot, eval/, scripts/ or any tracked file.
cd "$(dirname "$0")/.." || exit 1
yes=0; data=0
for a in "$@"; do case "$a" in --yes) yes=1 ;; --data) data=1 ;; *) echo "usage: reset-lab.sh [--yes] [--data]" >&2; exit 2 ;; esac; done

targets=()
for f in logs/* logs/.[!.]*; do [ -e "$f" ] && [ "$(basename "$f")" != ".gitkeep" ] && targets+=("$f"); done
if [ -d ../triage-work ]; then
  if [ -f ../triage-work/triage-prompt.txt ] || [ -d ../triage-work/logs ]; then targets+=("../triage-work")
  else echo "skipped ../triage-work: it does not look like the lab work folder" >&2; fi
fi
[ "$data" = 1 ] && [ -d data/mockito ] && targets+=("data/mockito")

if [ "${#targets[@]}" = 0 ]; then echo "Nothing to reset."; exit 0; fi
if [ "$yes" = 0 ]; then
  echo "Would delete (dry run, add --yes to delete):"; printf '  %s\n' "${targets[@]}"; exit 0
fi
echo "Deleting:"
for t in "${targets[@]}"; do printf '  %s\n' "$t"; rm -rf -- "$t"; done
mkdir -p logs; [ -f logs/.gitkeep ] || : > logs/.gitkeep
echo "Done. Run scripts/verify-lab.sh to check the lab."
