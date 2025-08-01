import re
from toolz import pipe
from toolz.curried import partitionby, filter as tfilter, map as tmap

pat_mark = re.compile(r"client settting.+")
pat_put = re.compile(r"MassTree-Workload put (?P<throughput>\d+) avg (?P<avg>\d+) p90 (?P<p90>\d+) p95 (?P<p95>\d+) p99 (?P<p99>\d+)")
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

        d_put = __worker(pat_put, xs)

        ret = {
            "throughput": d_put["throughput"],
            "duration": None,
            "latency_req": {
                "avg": d_put["avg"],
                "p90": d_put["p90"],
                "p95": d_put["p95"],
                "p99": d_put["p99"],
            },
        }
        return ret

    data = data.strip()
    results = pipe(
        data,
        _worker,
    )
    return results
