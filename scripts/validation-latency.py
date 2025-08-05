import os
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np

mpl.rcParams["font.sans-serif"] = "Times New Roman"
mpl.rcParams["font.family"] = "serif"
mpl.rcParams["pdf.fonttype"] = 42
mpl.rcParams["ps.fonttype"] = 42


def parse_cdf(filename):
    with open(os.path.join("results", filename)) as f:
        lines = f.readlines()[2:-3]
        tokens = [l.split() for l in lines]
        values = [float(t[0]) for t in tokens]
        percentiles = [float(t[1]) for t in tokens]
    return np.array(values), np.array(percentiles)


def fuck(x):
    return x[0] * 2, x[1]


def empty_cdf():
    return np.array([]), np.array([])


data = {
    "Memcached": {
        "RBV": parse_cdf("memcached-validation_latency-rbv.cdf"),
        "Orthrus": parse_cdf("memcached-validation_latency-orthrus.cdf"),
        "xlim": (0.3, 3e3),
    },
    "Masstree": {
        "RBV": parse_cdf("masstree-validation_latency-rbv.cdf"),
        "Orthrus": parse_cdf("masstree-validation_latency-orthrus.cdf"),
        "xlim": (1, 1e4),
    },
    "LSMTree": {
        "RBV": parse_cdf("lsmtree-validation_latency-rbv.cdf"),
        "Orthrus": parse_cdf("lsmtree-validation_latency-orthrus.cdf"),
        "xlim": (1, 2e3),
    },
    "Phoenix": {
        "RBV": parse_cdf("phoenix-validation_latency-rbv.cdf"),
        "Orthrus": parse_cdf("phoenix-validation_latency-orthrus.cdf"),
        "xlim": (1e5, 1.2e6),
    },
}

print("data loaded")

benchmarks = ["Memcached", "Phoenix", "Masstree", "LSMTree"]
systems = ["Orthrus", "RBV"]
# systems = ["Orthrus"]
markers = ["*", "s", "o", "+"]
colors = ["#D6851C", "#3D8E84", "#D14B3B", "#A07F4D"]
line_styles = ["-", "--", "-.", ":"]

X_LABEL = "Latency (μs)"
Y_LABEL = "Accumulated (%)"

TITLE_FONT_SIZE = 30
LABEL_FONT_SIZE = 28
TICK_FONT_SIZE = 28
LINE_WIDTH = 4
MARKER_SIZE = 14


fig, axes = plt.subplots(1, 4, figsize=(12, 3.6))

for sub_x, bench in enumerate(benchmarks):
    ax = axes[sub_x]
    ax.set_title(bench, fontsize=TITLE_FONT_SIZE, fontweight="bold", pad=12)
    ax.tick_params(axis="both", which="major", labelsize=TICK_FONT_SIZE)
    if sub_x == 0:
        ax.set_ylabel(Y_LABEL, fontsize=LABEL_FONT_SIZE, y=0.4)
        ax.set_xlabel(X_LABEL, fontsize=LABEL_FONT_SIZE)
    else:
        ax.set_yticks([])
    with_legend = sub_x == 0
    for system, color, line_style, marker in zip(systems, colors, line_styles, markers):
        values, percentiles = data[bench][system]
        xlim = data[bench]["xlim"]
        if len(values) > 32:
            x = []
            y = []
            last_x, last_y = -xlim[1], -1
            for xi, yi in zip(values, percentiles):
                if xi >= last_x * 2 or yi - last_y >= 0.1:
                    x.append(xi)
                    y.append(yi)
                    last_x, last_y = xi, yi
        else:
            x, y = values, percentiles
        # print(x, y)
        arg_label = {"label": system} if with_legend else {}
        ax.plot(
            np.array(x),
            np.array(y) * 100,
            line_style,
            marker=marker,
            color=color,
            linewidth=LINE_WIDTH,
            markersize=MARKER_SIZE,
            markerfacecolor="none",
            markeredgewidth=LINE_WIDTH,
            **arg_label,
        )
    ax.set_xscale("log")
    print(xlim)
    ax.set_xlim(xlim)
    ax.set_ylim((0, 100))
    if bench == "Phoenix":
        # 取消 minor ticks
        ax.tick_params(axis="x", which="minor", labelsize=0)


leg = fig.legend(loc="lower center", bbox_to_anchor=(0.6, -0.08), ncol=4, fontsize=28)
fig.subplots_adjust(top=0.85, bottom=0.3, left=0.12, right=0.98)
fig.subplots_adjust(hspace=0.25, wspace=0.25)

plt.savefig("validation-cdf.png")
plt.savefig("validation-cdf.pdf")
