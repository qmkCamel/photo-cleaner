import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("evaluate_recognition", Path(__file__).resolve().parents[1] / "evaluate_recognition.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class EvaluationTests(unittest.TestCase):
    def truth(self):
        return {"assetIDs": ["a", "b", "c", "d"], "similarGroups": [["a", "b"]], "exactGroups": [], "blurry": ["c"], "accidental": []}

    def test_split_merge_and_missed_quality_are_visible(self):
        actual = {"similarGroups": [["a", "b", "c"]], "exactGroups": [], "blurry": [], "accidental": ["d"]}
        result = module.evaluate(self.truth(), actual)
        self.assertEqual(result["similarGroups"]["precision"], 1 / 3)
        self.assertEqual(result["similarGroups"]["recall"], 1)
        self.assertEqual(result["blurry"]["false_negative"], 1)
        self.assertEqual(result["accidental"]["false_positive"], 1)

    def test_unknown_assets_and_overlapping_groups_fail(self):
        actual = self.truth()
        actual["blurry"] = ["unknown"]
        with self.assertRaises(ValueError):
            module.evaluate(self.truth(), actual)
        with self.assertRaises(ValueError):
            module.pairs([["a", "b"], ["b", "c"]])

    def test_empty_denominators_are_unknown_not_perfect(self):
        result = module.scores(set(), set())
        self.assertIsNone(result["precision"])
        self.assertIsNone(result["recall"])
