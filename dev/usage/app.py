#!/usr/bin/env python3
"""Claude Code daily token usage — bar chart viewer."""

import json
import os
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib.patches import Patch

PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

# Pricing per token by model family ($/token)
# Opus 4.x: $15 input, $75 output, $18.75 cache write, $1.50 cache read per MTok
# Sonnet 4.x: $3 input, $15 output, $3.75 cache write, $0.30 cache read per MTok
def model_rates(model: str) -> dict[str, float]:
    if "opus" in model:
        return {
            "input":        15.00 / 1_000_000,
            "output":       75.00 / 1_000_000,
            "cache_create": 18.75 / 1_000_000,
            "cache_read":    1.50 / 1_000_000,
        }
    # Default: Sonnet
    return {
        "input":        3.00 / 1_000_000,
        "output":      15.00 / 1_000_000,
        "cache_create": 3.75 / 1_000_000,
        "cache_read":   0.30 / 1_000_000,
    }

COLORS = {
    "cache_read":   "#93c5fd",  # blue-300
    "cache_create": "#3b82f6",  # blue-500
    "input":        "#f97316",  # orange-500
    "output":       "#22c55e",  # green-500
}

LABELS = {
    "cache_read":   "Cache Read",
    "cache_create": "Cache Write",
    "input":        "Input",
    "output":       "Output",
}


def collect(days: int) -> dict[date, dict[str, int | float]]:
    cutoff = date.today() - timedelta(days=days - 1)
    daily: dict[date, dict[str, int | float]] = defaultdict(
        lambda: {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0, "cost": 0.0}
    )
    for root, dirs, files in os.walk(PROJECTS_DIR):
        dirs[:] = [d for d in dirs if d != "subagents"]
        for fname in files:
            if not fname.endswith(".jsonl"):
                continue
            try:
                with open(os.path.join(root, fname), encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        if '"usage"' not in line:
                            continue
                        try:
                            obj = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        if obj.get("type") != "assistant":
                            continue
                        msg = obj.get("message", {})
                        usage = msg.get("usage")
                        if not usage:
                            continue
                        ts = obj.get("timestamp", "")
                        if not ts:
                            continue
                        try:
                            record_date = datetime.fromisoformat(ts.replace("Z", "+00:00")).date()
                        except ValueError:
                            continue
                        if record_date < cutoff:
                            continue
                        rates = model_rates(msg.get("model", ""))
                        inp = usage.get("input_tokens", 0)
                        out = usage.get("output_tokens", 0)
                        cc  = usage.get("cache_creation_input_tokens", 0)
                        cr  = usage.get("cache_read_input_tokens", 0)
                        d = daily[record_date]
                        d["input"]        += inp
                        d["output"]       += out
                        d["cache_create"] += cc
                        d["cache_read"]   += cr
                        d["cost"]         += (inp * rates["input"] + out * rates["output"]
                                              + cc * rates["cache_create"] + cr * rates["cache_read"])
            except (OSError, IOError):
                continue
    return daily


def fmt_tok(n: int) -> str:
    if n >= 1_000_000_000:
        return f"{n/1_000_000_000:.1f}B"
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.0f}k"
    return str(n)


def plot(daily: dict, days: int) -> None:
    # Fill every day in range (even empty ones)
    today = date.today()
    cutoff = today - timedelta(days=days - 1)
    all_days = [cutoff + timedelta(d) for d in range(days)]

    segments = ["cache_read", "cache_create", "input", "output"]
    data = {k: [daily.get(d, {}).get(k, 0) for d in all_days] for k in segments}
    costs = [daily.get(d, {}).get("cost", 0.0) for d in all_days]

    fig, (ax_bar, ax_cost) = plt.subplots(
        2, 1,
        figsize=(max(12, days * 0.55), 8),
        gridspec_kw={"height_ratios": [3, 1]},
        sharex=True,
    )
    fig.patch.set_facecolor("#0f172a")
    for ax in (ax_bar, ax_cost):
        ax.set_facecolor("#1e293b")
        ax.tick_params(colors="#94a3b8")
        ax.spines[:].set_color("#334155")

    x = list(range(len(all_days)))
    bar_w = 0.7
    bottoms = [0] * len(all_days)

    bars_by_seg = {}
    for seg in segments:
        vals = data[seg]
        bars = ax_bar.bar(x, vals, bar_w, bottom=bottoms, color=COLORS[seg], label=LABELS[seg])
        bars_by_seg[seg] = (bars, vals, list(bottoms))
        bottoms = [b + v for b, v in zip(bottoms, vals)]

    # Annotate total tokens on each bar
    for i, (_, total) in enumerate(zip(all_days, bottoms)):
        if total > 0:
            ax_bar.text(
                i, total + max(bottoms) * 0.01,
                fmt_tok(total),
                ha="center", va="bottom",
                fontsize=7, color="#cbd5e1",
            )

    # Cost bars (secondary chart)
    ax_cost.bar(x, costs, bar_w, color="#a78bfa", alpha=0.8)
    for i, c in enumerate(costs):
        if c > 0.5:
            ax_cost.text(i, c + max(costs) * 0.02, f"${c:.0f}", ha="center",
                         va="bottom", fontsize=7, color="#c4b5fd")

    # X axis — dates
    ax_cost.set_xticks(x)
    ax_cost.set_xticklabels(
        [d.strftime("%b %-d") for d in all_days],
        rotation=45, ha="right", fontsize=8, color="#94a3b8",
    )

    # Highlight today
    if today in all_days:
        ti = all_days.index(today)
        for ax in (ax_bar, ax_cost):
            ax.axvline(ti, color="#f8fafc", alpha=0.15, linewidth=1.5, linestyle="--")
        ax_bar.text(ti, max(bottoms) * 1.02, "today", ha="center",
                    fontsize=7, color="#f8fafc", alpha=0.6)

    # Y axis formatting
    ax_bar.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: fmt_tok(int(v))))
    ax_bar.tick_params(axis="y", labelsize=8)
    ax_cost.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"${v:.0f}"))
    ax_cost.tick_params(axis="y", labelsize=8)

    # Labels / titles
    total_tok = sum(bottoms)
    total_cost = sum(costs)
    fig.suptitle(
        f"Claude Code Token Usage — last {days} days   |   "
        f"Total: {fmt_tok(total_tok)} tokens  ≈  ${total_cost:.0f}",
        color="#f1f5f9", fontsize=13, fontweight="bold", y=0.98,
    )
    ax_bar.set_ylabel("Tokens", color="#94a3b8", fontsize=9)
    ax_cost.set_ylabel("Est. Cost", color="#94a3b8", fontsize=9)

    # Legend
    legend_patches = [Patch(color=COLORS[s], label=LABELS[s]) for s in segments]
    ax_bar.legend(
        handles=legend_patches, loc="upper left",
        framealpha=0.2, facecolor="#0f172a",
        labelcolor="#e2e8f0", fontsize=8,
    )

    plt.tight_layout(rect=(0, 0, 1, 0.97))
    plt.show()


def main() -> None:
    args = sys.argv[1:]
    days = 30
    if args and args[0].lstrip("-").isdigit():
        days = abs(int(args[0]))

    print(f"Scanning session files for last {days} days…", flush=True)
    daily = collect(days)
    if not daily:
        print("No usage data found.")
        return
    plot(daily, days)


if __name__ == "__main__":
    main()
