import json
import re
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-i", "--input", required=True)
parser.add_argument("-o", "--output", required=True)

args = parser.parse_args()

with open(args.input, "r") as f:
    lines = f.read().strip().splitlines()

pat1 = re.compile(r".+Time taken: (\d+) ms")
assert(len(lines) == 6)

raw = pat1.match(lines[1])[1]
scee = pat1.match(lines[3])[1]
rbv = pat1.match(lines[5])[1]

with open(args.output, "w") as f:
    json.dump({
        "vanilla": {
            "duration": raw,
        },
        "orthrus": {
            "duration": scee,
        },
        "rbv": {
            "duration": scee,
        },
    }, f, indent=2, ensure_ascii=False)
