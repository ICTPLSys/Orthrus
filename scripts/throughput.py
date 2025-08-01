"""
Plot evaluation throughput
"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import ScalarFormatter
import json

RESULTS_DIR = "results/"

mpl.rcParams["font.sans-serif"] = "Times New Roman"
mpl.rcParams["font.family"] = "serif"
mpl.rcParams["pdf.fonttype"] = 42
mpl.rcParams["ps.fonttype"] = 42


def parse_throughput(filename: str):
    with open(filename, "r") as f:
        data = json.load(f)
    return {
        "Vanilla": float(data["vanilla"]["throughput"]) / 1000,
        "Orthrus": float(data["orthrus"]["throughput"]) / 1000,
        "RBV": float(data["rbv"]["throughput"]) / 1000,
    }


def parse_duration(filename: str):
    with open(filename, "r") as f:
        data = json.load(f)
    return {
        "Vanilla": float(data["vanilla"]["duration"]) / 1000,
        "Orthrus": float(data["orthrus"]["duration"]) / 1000,
        "RBV": float(data["rbv"]["duration"]) / 1000,
    }


data = {
    "Memcached": parse_throughput(RESULTS_DIR + "memcached-throughput-report.txt.json"),
    "Masstree": parse_throughput(RESULTS_DIR + "masstree-throughput-report.txt.json"),
    "LSMTree": parse_throughput(RESULTS_DIR + "lsmtree-throughput-report.txt.json"),
    "Phoenix": parse_duration(RESULTS_DIR + "phoenix-throughput-report.txt.json"),
}


TITLE_FONT_SIZE = 30
LABEL_FONT_SIZE = 28
TICK_FONT_SIZE = 24
TICK_MINOR_FONT_SIZE = 16
HEIGHT_TEXT = 24
LINE_WIDTH = 4
MARKER_SIZE = 14

WIDTH = 0.5

# COLORS = ["#8ECFC9", "#FFBE7A", "#FA7F6F", "#F5F5DC"]
COLORS = ["#9CB3D4", "#D6851C", "#3D8E84"]
SYSTEMS = ["Vanilla", "Orthrus", "RBV"]

fig, axes = plt.subplots(2, 2, figsize=(12, 10))


def format_bar_height(val, expo=None):
    if expo is not None:
        val /= 10**expo
        return f"{val:.2f}"
    if val < 1e2:
        return f"{val:.1f}"
    return f"{int(val)}"


def plot_fig(ax: plt.Axes, name, ylabel, with_legend, ylim=None, expo=None):
    bars = []
    for system, x, color in zip(SYSTEMS, range(len(SYSTEMS)), COLORS):
        height = [data[name][system], data[name][system]]
        arg_legend = {"label": system} if with_legend else {}
        bars += ax.bar(
            [x],
            height,
            color=color,
            ec="k",
            ls="-",
            width=WIDTH,
            **arg_legend,
        )
    for bar in bars:
        tx = bar.get_x() + WIDTH / 2
        ty = bar.get_height()
        text = format_bar_height(ty, expo)
        ax.text(tx, ty, text, ha="center", va="bottom", fontsize=HEIGHT_TEXT)
    ax.set_ylabel(ylabel, fontsize=LABEL_FONT_SIZE)
    ax.set_title(name, fontsize=TITLE_FONT_SIZE)
    ax.set_xticks(np.arange(len(SYSTEMS)))
    ax.set_xticklabels([""] * len(SYSTEMS), fontsize=LABEL_FONT_SIZE, rotation=15)
    ax.tick_params(axis="y", which="major", labelsize=TICK_FONT_SIZE)
    ax.tick_params(axis="y", which="minor", labelsize=TICK_MINOR_FONT_SIZE)
    # ax.set_yscale("log")
    ax.set_ylim((None, ylim))

    formatter = ScalarFormatter(useMathText=True)
    formatter.set_scientific(True)
    formatter.set_powerlimits((0, 4))
    ax.yaxis.set_major_formatter(formatter)
    ax.yaxis.get_offset_text().set_fontsize(TICK_MINOR_FONT_SIZE)
    ax.figure.canvas.draw()


plot_fig(axes[0, 0], "Memcached", "Throughput (Kops)", True, 500)
plot_fig(axes[0, 1], "Phoenix", "Elapsed Time (s)", False, 50)
plot_fig(axes[1, 0], "Masstree", "Throughput (Kops)", False, 700)
plot_fig(axes[1, 1], "LSMTree", "Throughput (Kops)", False, 220)

leg = fig.legend(loc="lower center", bbox_to_anchor=(0.5, -0.08), ncol=4, fontsize=28)
fig.subplots_adjust(top=0.9, bottom=0.05, left=0.1, right=0.95)
fig.subplots_adjust(hspace=0.2, wspace=0.4)

plt.savefig("results/img/throughput.png", bbox_inches="tight")
plt.savefig("results/img/throughput.pdf", bbox_inches="tight")
