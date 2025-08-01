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

scee = parse(args.input_scee)

rbv = parse(args.input_rbv)

with open(args.output, "w") as fout:
    fout.write("vanilla running\n")
    fout.write(f"throughput: {raw['throughput']}\n")
    fout.write("orthrus running\n")
    fout.write(f"throughput: {scee['throughput']}\n")
    fout.write("rbv running\n")
    fout.write(f"throughput: {rbv['throughput']}\n")

with open(f"{args.output}.json", "w") as fout:
    json.dump({
        "vanilla": raw,
        "orthrus": scee,
        "rbv": rbv,
    }, fout, ensure_ascii=False, indent=2)
