#!/usr/bin/env python3
"""Compare a labeled local dataset with TrueKeep's exported review report."""
import argparse
import itertools
import json
from pathlib import Path


def pairs(groups):
    result = set()
    seen = set()
    for group in groups:
        if len(group) < 2 or len(set(group)) != len(group):
            raise ValueError("Each group needs at least two unique IDs")
        if seen.intersection(group):
            raise ValueError("Groups within a category must not overlap")
        seen.update(group)
        result.update(itertools.combinations(sorted(group), 2))
    return result


def scores(expected, actual):
    tp = len(expected & actual)
    fp = len(actual - expected)
    fn = len(expected - actual)
    return {
        "true_positive": tp, "false_positive": fp, "false_negative": fn,
        "precision": tp / (tp + fp) if tp + fp else None,
        "recall": tp / (tp + fn) if tp + fn else None,
    }


def evaluate(truth, prediction):
    asset_ids = set(truth["assetIDs"])
    if not asset_ids:
        raise ValueError("A labeled dataset must declare non-empty assetIDs")
    result = {"asset_count": len(asset_ids), "dataset": truth.get("name", "unnamed")}
    for field in ("similarGroups", "exactGroups", "blurry", "accidental"):
        expected_values = truth[field]
        actual_values = prediction[field]
        if field.endswith("Groups"):
            ids = set(itertools.chain.from_iterable(expected_values + actual_values))
            expected, actual = pairs(expected_values), pairs(actual_values)
        else:
            ids = set(expected_values + actual_values)
            expected, actual = set(expected_values), set(actual_values)
        if not ids.issubset(asset_ids):
            raise ValueError(f"{field} contains IDs outside the labeled dataset")
        result[field] = scores(expected, actual)
    result["performance"] = prediction.get("report")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--truth", required=True, type=Path)
    parser.add_argument("--prediction", required=True, type=Path)
    args = parser.parse_args()
    result = evaluate(json.loads(args.truth.read_text()), json.loads(args.prediction.read_text()))
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
