#!/usr/bin/env bash
#
# SwiftBar plugin: memory + compressor readout for a RAM-constrained Mac.
#
# The filename is the config: "memory.3s.sh" tells SwiftBar to re-run this
# every 3 seconds. Change the "3s" to "5s"/"10s" to slow it down (each run is
# a couple of cheap sysctl/vm_stat calls, so 3s is fine).
#
# WHY this exists, and why the compressor is the headline number:
# On 8 GB, "free RAM" is a poor health signal — macOS deliberately keeps free
# RAM near zero and instead COMPRESSES cold pages in place (the "memory
# compressor") rather than paging them to disk. That's good until the
# compressor gets large: every access to a compressed page costs a CPU
# decompress, so a big compressor is the early warning that the machine is
# about to feel slow — well before swap usage shows it. vm_stat exposes the
# figure as "Pages occupied by compressor"; we surface it directly.
#
# Everything here is read-only (sysctl + vm_stat); the plugin never changes
# system state.

# SwiftBar runs plugins with a minimal environment, so set an explicit PATH
# rather than assuming the login shell's.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

page=$(sysctl -n hw.pagesize)   # 16384 on Apple Silicon, 4096 on Intel — read
                                # it rather than hard-coding, so this is portable
total=$(sysctl -n hw.memsize)   # physical RAM, in bytes

# vm_stat reports every figure as a count of pages, with a trailing '.' on each
# number. Strip the dots and pull the fields we need in one awk pass.
eval "$(vm_stat | sed 's/\.//' | awk -F: '
  /Pages free/             {gsub(/ /,"",$2); printf "free=%d;",     $2}
  /Pages active/           {gsub(/ /,"",$2); printf "active=%d;",   $2}
  /Pages inactive/         {gsub(/ /,"",$2); printf "inactive=%d;", $2}
  /Pages speculative/      {gsub(/ /,"",$2); printf "spec=%d;",     $2}
  /Pages wired down/       {gsub(/ /,"",$2); printf "wired=%d;",    $2}
  /occupied by compressor/ {gsub(/ /,"",$2); printf "comp=%d;",     $2}
')"

pages_to_bytes() { echo "$(( $1 * page ))"; }
gb() { awk -v b="$1" 'BEGIN{printf "%.1fG", b/1073741824}'; }

comp_b=$(pages_to_bytes "$comp")
wired_b=$(pages_to_bytes "$wired")
active_b=$(pages_to_bytes "$active")

# "Available" = pages macOS can hand out without paging anything: genuinely
# free, plus inactive/speculative (clean, cheaply reclaimable). "Used" is the
# rest. This tracks the reclaimable/non-reclaimable split, not Activity
# Monitor's exact "Memory Used" formula — the components below are each exact.
avail_b=$(( $(pages_to_bytes "$free") + $(pages_to_bytes "$inactive") + $(pages_to_bytes "$spec") ))
used_b=$(( total - avail_b ))

# Swap: sysctl prints "... used = 199.56M ..."; lift just the used field.
swap_used=$(sysctl -n vm.swapusage | sed -n 's/.*used = \([0-9.]*[A-Za-z]*\).*/\1/p')

# Colour the bar by compressor size — the whole point is to notice it climbing
# without reading the number. Bands (GB of compressed data), tuned for 8 GB:
#   < 1.2G  grey   — comfortable
#   1.2-2G  amber  — getting tight, think about closing a browser/Claude
#   >= 2G   red    — actively thrashing; the machine is spending CPU on this
comp_gb=$(awk -v b="$comp_b" 'BEGIN{printf "%.2f", b/1073741824}')
color="#8a8a8a"
awk -v v="$comp_gb" 'BEGIN{exit !(v>=1.2 && v<2.0)}' && color="#d29922"
awk -v v="$comp_gb" 'BEGIN{exit !(v>=2.0)}'          && color="#e5534b"

# --- Menu-bar line (everything before the first "---") ---
echo "RAM $(gb $used_b)  CMP $(gb $comp_b) | color=$color font=Menlo size=12"

# --- Dropdown ---
echo "---"
echo "Memory on $(gb $total) machine | size=13"
echo "Used         $(gb $used_b) | font=Menlo"
echo "-- Wired     $(gb $wired_b) | font=Menlo size=12"
echo "-- Active    $(gb $active_b) | font=Menlo size=12"
echo "-- Compressed $(gb $comp_b) | font=Menlo color=$color"
echo "Available    $(gb $avail_b) | font=Menlo"
echo "Swap used    ${swap_used:-0} | font=Menlo"
echo "---"
echo "Open Activity Monitor | bash='/System/Applications/Utilities/Activity Monitor.app/Contents/MacOS/Activity Monitor' terminal=false"
echo "Refresh now | refresh=true"
