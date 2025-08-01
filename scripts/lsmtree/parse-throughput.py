import json
import re
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-i", "--input", required=True)
parser.add_argument("-o", "--output", required=True)

args = parser.parse_args()

with open(args.input, "r") as f:
    lines = f.read().strip().splitlines()

pat1 = re.compile(r"execution time: (\d+), throughput: (.+)")
assert(len(lines) == 6)

raw = pat1.match(lines[1])[2]
scee = pat1.match(lines[3])[2]
rbv = pat1.match(lines[5])[2]

with open(args.output, "w") as f:
    json.dump({
        "vanilla": {
            "throughput": raw,
        },
        "orthrus": {
            "throughput": scee,
        },
        "rbv": {
            "throughput": rbv,
        },
    }, f, indent=2, ensure_ascii=False)
