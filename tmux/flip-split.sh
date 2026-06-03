#!/bin/sh
# Flip the current window's split orientation: side-by-side <-> stacked.
#
# Lives in a file (not inline in the binding) because tmux's run-shell expands
# its command string through FORMATS first, and `${#H}`/`${#V}` collide with the
# `#H` (hostname) format code. Script contents are read by /bin/sh, so they are
# safe from that expansion.

L=$(tmux display -p '#{window_layout}')

# window_layout starts with "csum,WxH,X,Y" then a grouping char: '{' for a
# left/right row (side-by-side) or '[' for a top/bottom column (stacked).
# Whichever delimiter appears first marks the top-level orientation.
H=${L%%\{*}   # text before first '{'  ('{' => side-by-side)
V=${L%%[[]*}  # text before first '['  ('[' => stacked)

if [ ${#H} -le ${#V} ]; then
  tmux select-layout even-vertical   # currently side-by-side -> stack it
else
  tmux select-layout even-horizontal # currently stacked -> spread side-by-side
fi
