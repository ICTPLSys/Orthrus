import os
import json
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np

mpl.rcParams["font.sans-serif"] = "Times New Roman"
mpl.rcParams["font.family"] = "serif"
mpl.rcParams["pdf.fonttype"] = 42
mpl.rcParams["ps.fonttype"] = 42


def parse_json(file_path):
    print(f"parsing {file_path}")
    with open(os.path.join("results", file_path), "r", encoding="ascii") as f:
        json_data = json.load(f)
    json_data = list(filter(lambda x: "throughput" in x and "latency_req" in x and "p95" in x["latency_req"], json_data))
    all_data = np.array([(t["throughput"], t["latency_req"]["p95"]) for t in json_data])
    all_data = np.sort(all_data, axis=0)
    throughput = all_data[:, 0]
    latency = all_data[:, 1]
    return throughput, latency


memcached_throughput_scee, memcached_latency_scee = parse_json("memcached-latency_vs_pXX-orthrus.json")
memcached_throughput_raw, memcached_latency_raw = parse_json("memcached-latency_vs_pXX-vanilla.json")
memcached_throughput_rbv, memcached_latency_rbv = parse_json("memcached-latency_vs_pXX-rbv.json")

lsmtree_throughput_scee, lsmtree_latency_scee = parse_json("lsmtree-latency_vs_pXX-orthrus.json")
lsmtree_throughput_raw, lsmtree_latency_raw = parse_json("lsmtree-latency_vs_pXX-vanilla.json")
lsmtree_throughput_rbv, lsmtree_latency_rbv = parse_json("lsmtree-latency_vs_pXX-rbv.json")

data = {
    "Memcached": {
        "RBV": {
            "throughput": memcached_throughput_rbv,
            "p95": memcached_latency_rbv * 1e3,
        },
        "Orthrus": {
            "throughput": memcached_throughput_scee,
            "p95": memcached_latency_scee * 1e3,
        },
        "Vanilla": {
            "throughput": memcached_throughput_raw,
            "p95": memcached_latency_raw * 1e3,
        },
    },
    "LSMTree": {
        "RBV": {
            "throughput": lsmtree_throughput_rbv,
            "p95": lsmtree_latency_rbv * 1e3,
        },
        "Orthrus": {
            "throughput": lsmtree_throughput_scee,
            "p95": lsmtree_latency_scee * 1e3,
        },
        "Vanilla": {
            "throughput": lsmtree_throughput_raw,
            "p95": lsmtree_latency_raw * 1e3,
        },
    },
}

benchmarks = ["Memcached", "LSMTree"]
systems = ["Vanilla", "Orthrus", "RBV"]
markers = ["*", "s", "o", "+"]
colors = ["#9CB3D4", "#D6851C", "#3D8E84", "#A07F4D", "#D14B3B"]
line_styles = ["-", "--", "-.", ":"]

X_LABEL = "Throughput (KOp/s)"
Y_LABEL = "95% Tail \nLatency (μs)"

TITLE_FONT_SIZE = 30
LABEL_FONT_SIZE = 26
TICK_FONT_SIZE = 24
TICK_FONT_SIZE_MINOR = 20
LINE_WIDTH = 4
MARKER_SIZE = 14

# XLIM = (0, 200)

fig, axes = plt.subplots(1, len(benchmarks), figsize=(12, 4))

for sub_i, bench in enumerate(benchmarks):
    ax = axes[sub_i]
    ax.set_title(bench, fontsize=TITLE_FONT_SIZE, fontweight="bold")
    ax.tick_params(axis="both", which="major", labelsize=TICK_FONT_SIZE)
    ax.tick_params(axis="both", which="minor", labelsize=TICK_FONT_SIZE_MINOR)
    ax.set_xlabel(X_LABEL, fontsize=LABEL_FONT_SIZE)
    if sub_i == 0:
        ax.set_ylabel(Y_LABEL, fontsize=LABEL_FONT_SIZE)
    with_legend = sub_i == 0
    ymax = 0
    for system, color, line_style, marker in zip(systems, colors, line_styles, markers):
        xy = list(
            zip(
                data[bench][system]["throughput"],
                data[bench][system]["p95"],
            )
        )
        xy = sorted(xy)
        x = np.array([xi for xi, _ in xy])
        y = np.array([yi for _, yi in xy])
        x, y = x / 1000, y * 0.001
        n = max(1, len(x) // 8)
        #  n = 1
        x = x[::n]
        y = y[::n]
        if bench == "Memcached":
            x = x[:-1]
            y = y[:-1]
        arg_label = {"label": system} if with_legend else {}
        ax.plot(
            x,
            y,
            line_style,
            marker=marker,
            color=color,
            linewidth=LINE_WIDTH,
            markersize=MARKER_SIZE,
            markerfacecolor="none",
            markeredgewidth=LINE_WIDTH,
            **arg_label,
        )
        # ax.set_xlim(XLIM)
        if bench == "Memcached-":
            ax.set_yscale("log")
        else:
            if len(y) > 0:
                ymax = max(ymax, max(y))
                ax.set_ylim((0, min(ymax * 1.1, 1000)))


leg = fig.legend(loc="lower center", bbox_to_anchor=(0.5, -0.03), ncol=4, fontsize=24)
fig.subplots_adjust(top=0.85, bottom=0.4, left=0.2, right=0.8)
fig.subplots_adjust(wspace=0.5)

plt.savefig("tail-latency.png")
plt.savefig("tail-latency.pdf")
