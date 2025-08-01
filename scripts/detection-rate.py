import json
import enum
import numpy as np


class ErrorType(enum.Enum):
    SDC_DETECTED = "SDC_DETECTED"
    SDC_NOT_DETECTED = "SDC_NOT_DETECTED"
    MASKED = "MASKED"
    FAIL_STOP = "FAIL_STOP"


def get_error_type(injection_result: dict):
    err_type = injection_result["error"]
    err_log = injection_result["data"]["err"]

    if any("SDC Not" in line for line in err_log):
        return ErrorType.SDC_NOT_DETECTED
    elif any("Validation failed" in line for line in err_log):
        assert err_type == "RunResult.ErrorDetected"
        return ErrorType.SDC_DETECTED
    elif err_type != "RunResult.Success":
        return ErrorType.FAIL_STOP
    else:
        return ErrorType.MASKED


def get_fn_name(injection: dict):
    name_tokens = injection["name"].split("|")
    if len(name_tokens) == 6:
        _, fn_name, _pc, _hw_type, _unit_type, _inst_name = name_tokens
    elif len(name_tokens) == 7:
        _, fn_name, _pc, _hw_type, _, _unit_type, _inst_name = name_tokens
    return fn_name


P = 0.02


def run(filename: str, a: float, n: int, ncpu: int):
    # parse

    with open(filename, "r") as f:
        data = json.load(f)

    detectable = {}
    not_detectable = {}

    for fn_result in data.values():
        for injection in fn_result["injection"]:
            fn_name = get_fn_name(injection)
            err_type = get_error_type(injection["result"])
            if err_type == ErrorType.SDC_DETECTED:
                if fn_name not in detectable:
                    detectable[fn_name] = 1
                else:
                    detectable[fn_name] += 1
            elif err_type == ErrorType.SDC_NOT_DETECTED:
                if fn_name not in not_detectable:
                    not_detectable[fn_name] = 1
                else:
                    not_detectable[fn_name] += 1

    functions = set()
    for fn_name in detectable:
        functions.add(fn_name)
    for fn_name in not_detectable:
        functions.add(fn_name)

    total_detectable = sum(detectable.values())
    total_not_detectable = sum(not_detectable.values())
    total = total_detectable + total_not_detectable

    # simulate
    fn_list = list(functions)
    np.random.shuffle(fn_list)
    w = [1 / (r**a) for r in range(1, len(fn_list) + 1)]
    p = [wi / sum(w) for wi in w]
    fn_exec = np.random.choice(fn_list, size=n, p=p, replace=True)

    def random_sampling(sampling_rate: float):
        detected = set()
        for fn in fn_exec:
            if fn not in detectable:
                assert fn in fn_list
                assert fn in not_detectable
                continue
            for i in range(detectable[fn]):
                if np.random.random() < sampling_rate and np.random.random() < P:
                    detected.add((fn, i))
        return len(detected) / total

    def orthrus_sampling(sampling_rate: float):
        detected = set()
        max_win_size = 1000
        win_size = 0
        win = {fn: 0 for fn in fn_list}

        def validate():
            nonlocal win_size, win, max_win_size, detected
            nv = 0
            max_nv = sampling_rate * win_size
            while nv < max_nv:
                for fn in win:
                    if win[fn] == 0:
                        continue
                    win[fn] -= 1
                    for i in range(detectable[fn]):
                        if np.random.random() < P:
                            detected.add((fn, i))
                    nv += 1
                    if nv >= max_nv:
                        break
            win = {fn: 0 for fn in fn_list}
            win_size = 0

        for fn in fn_exec:
            if win_size < max_win_size:
                win[fn] += 1
                win_size += 1
            else:
                validate()
        validate()

        return len(detected) / total

    X = np.arange(ncpu) + 1
    Yrandom = [random_sampling(x / ncpu) for x in X]
    Yorthrus = [orthrus_sampling(x / ncpu) for x in X]
    return {
        "Random": [X, np.array(Yrandom)],
        "Orthrus": [X, np.array(Yorthrus)],
        "xlim": ncpu + 1,
    }


def get_filename(bench: str):
    return f"results/fault_injection/{bench}.json"


# draw
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np

mpl.rcParams["font.sans-serif"] = "Times New Roman"
mpl.rcParams["font.family"] = "serif"
mpl.rcParams["pdf.fonttype"] = 42
mpl.rcParams["ps.fonttype"] = 42

data = {
    "Memcached": run(get_filename("memcached"), 1.2, 50000, 4),
    "Masstree": run(get_filename("masstree"), 1.2, 10000, 4),
    "LSMTree": run(get_filename("lsmtree"), 1.5, 4000, 4),
    "Phoenix": run(get_filename("phoenix"), 1.2, 10000, 8),
}

benchmarks = ["Memcached", "Phoenix", "Masstree", "LSMTree"]
systems = ["Orthrus", "Random"]
markers = ["*", "s", "o", "+"]
colors = ["#D6851C", "#3D8E84", "#D14B3B", "#A07F4D"]
line_styles = ["-", "--", "-.", ":"]

X_LABEL = "Cores"
Y_LABEL = "Detection Rate (%)"

TITLE_FONT_SIZE = 28
LABEL_FONT_SIZE = 28
TICK_FONT_SIZE = 28
LINE_WIDTH = 4
MARKER_SIZE = 14

fig, axes = plt.subplots(1, 4, figsize=(12, 4))

for sub_x, bench in enumerate(benchmarks):
    ax = axes[sub_x]
    ax.set_title(bench, fontsize=TITLE_FONT_SIZE, fontweight="bold", pad=20)
    ax.tick_params(axis="both", which="major", labelsize=TICK_FONT_SIZE)
    if sub_x == 0:
        ax.set_ylabel(Y_LABEL, fontsize=LABEL_FONT_SIZE, y=0.45)
        ax.set_xlabel(X_LABEL, fontsize=LABEL_FONT_SIZE)
    else:
        ax.set_yticks([])
    with_legend = sub_x == 0
    for system, color, line_style, marker in zip(systems, colors, line_styles, markers):
        values, percentiles = data[bench][system]
        xlim = data[bench]["xlim"]
        x = data[bench][system][0]
        y = data[bench][system][1]

        arg_label = {"label": system} if with_legend else {}
        ax.plot(
            np.array(x),
            np.array(y * 100),
            line_style,
            marker=marker,
            color=color,
            linewidth=LINE_WIDTH,
            markersize=MARKER_SIZE,
            markerfacecolor="none",
            markeredgewidth=LINE_WIDTH,
            **arg_label,
        )
    ax.set_xlim((0, xlim))
    ax.set_ylim((0, 100))
    if xlim > 5:
        ax.set_xticks(np.arange(min(x), max(x) + 1, 2))
    else:
        ax.set_xticks(np.arange(min(x), max(x) + 1, 1))

leg = fig.legend(loc="lower center", bbox_to_anchor=(0.6, -0.08), ncol=4, fontsize=28)
fig.subplots_adjust(top=0.73, bottom=0.3, left=0.12, right=0.95)
fig.subplots_adjust(hspace=0.2, wspace=0.2)

plt.savefig("results/img/detection-rate.png")
plt.savefig("results/img/detection-rate.pdf")
