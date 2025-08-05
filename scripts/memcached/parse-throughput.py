import json
import argparse

from utils import parse


parser = argparse.ArgumentParser()
parser.add_argument("--input-raw", required=True)
parser.add_argument("--input-scee", required=True)
parser.add_argument("--input-rbv", required=True)
parser.add_argument("-o", "--output", required=True)

args = parser.parse_args()

raw = parse(args.input_raw)
assert len(raw) == 1

scee = parse(args.input_scee)
assert len(scee) == 1

rbv = parse(args.input_rbv)
assert len(rbv) == 1

with open(args.output, "w") as fout:
    fout.write("vanilla running\n")
    fout.write(f"throughput: {raw[0]['throughput']}\n")
    fout.write("orthrus running\n")
    fout.write(f"throughput: {scee[0]['throughput']}\n")
    fout.write("rbv running\n")
    fout.write(f"throughput: {rbv[0]['throughput']}\n")

with open(f"{args.output}.json", "w") as fout:
    json.dump({
        "vanilla": raw[0],
        "orthrus": scee[0],
        "rbv": rbv[0],
    }, fout, ensure_ascii=False, indent=2)
