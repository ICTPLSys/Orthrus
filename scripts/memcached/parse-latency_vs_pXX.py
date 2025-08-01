import re
import os
import json
import argparse
from toolz import pipe
from toolz.curried import partitionby, filter as tfilter, map as tmap

from utils import parse


parser = argparse.ArgumentParser()
parser.add_argument("-i", "--input", required=True)
parser.add_argument("-o", "--output", required=True)

args = parser.parse_args()

data = parse(args.input)

with open(args.output, "w") as f:
    json.dump(data, f, ensure_ascii=True, indent=2)
