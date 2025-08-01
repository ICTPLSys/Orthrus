import re
from toolz import pipe
from toolz.curried import partitionby, filter as tfilter, map as tmap

# client setting ngroups=3, nclients=32, nsets=50331648, ngets=524288, rps=0
pat_mark = re.compile(r"client settting.+")
# SET put 387807 avg 77712 p90 86722 p95 89712 p99 231960
pat_set = re.compile(r"SET put (?P<throughput>\d+) avg (?P<avg>\d+) p90 (?P<p90>\d+) p95 (?P<p95>\d+) p99 (?P<p99>\d+)")
# UPDATE put 365130 avg 84194 p90 91366 p95 94937 p99 243115
pat_update = re.compile(r"UPDATE put (?P<throughput>\d+) avg (?P<avg>\d+) p90 (?P<p90>\d+) p95 (?P<p95>\d+) p99 (?P<p99>\d+)")
# GET put 373528 avg 85134 p90 90945 p95 94510 p99 255360
pat_get    = re.compile(r"GET put (?P<throughput>\d+) avg (?P<avg>\d+) p90 (?P<p90>\d+) p95 (?P<p95>\d+) p99 (?P<p99>\d+)")
def parse(file):
    with open(file, encoding="utf8") as f:
        data = f.read().strip()

    def _worker(xs):
        def __worker(pat, line):
            if match := pat.match(line):
                return {
                    "throughput": int(match["throughput"]),
                    "avg": int(match["avg"]),
                    "p90": int(match["p90"]),
                    "p95": int(match["p95"]),
                    "p99": int(match["p99"]),
                }
            raise Exception("invalid data: ", pat, line)

        d_set = __worker(pat_set, xs[0])
        d_update = __worker(pat_update, xs[1])
        d_get = __worker(pat_get, xs[2])

        ret = {
            "throughput": (d_update["throughput"] + d_get["throughput"]) / 2,
            "duration": None,
            "latency_req": {
                "avg": (d_update["avg"] + d_get["avg"]) / 2 / 1000,
                "p90": (d_update["p90"] + d_get["p90"]) / 2 / 1000,
                "p95": (d_update["p95"] + d_get["p95"]) / 2 / 1000,
                "p99": (d_update["p99"] + d_get["p99"]) / 2 / 1000,
            },
        }
        return ret

    is_delimiter = lambda line: line.startswith('client setting')
    results = pipe(
        data.strip().splitlines(),
        partitionby(is_delimiter),
        tfilter(lambda group: not is_delimiter(group[0])),
        lambda xs: [_worker(x) for x in xs],
    )
    return results
