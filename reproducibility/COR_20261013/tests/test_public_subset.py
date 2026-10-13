"""Small regression tests for the public adapter and frozen statistical kernels."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("public_reproduce", ROOT / "reproduce.py")
reproduce = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reproduce)


class PublicSubsetTests(unittest.TestCase):
    def test_manifest_and_python_syntax(self):
        self.assertTrue(reproduce.verify_package()["integrity_passed"])

    def test_reject_path_escape(self):
        with self.assertRaises(ValueError):
            reproduce.safe_path(ROOT, "../outside.txt")

    def test_reject_immutable_outputs(self):
        for name in ("source_data", "analysis", "matlab", "tests", "evidence"):
            with self.assertRaises(ValueError):
                reproduce.prepare_output(ROOT / name / "new")
        with self.assertRaises(ValueError):
            reproduce.prepare_output(ROOT.parent)

    def test_reject_existing_output(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as name:
            destination = Path(name)
            (destination / "keep.txt").write_text("do not overwrite", encoding="utf-8")
            with self.assertRaises(ValueError):
                reproduce.prepare_output(destination)
            self.assertEqual((destination / "keep.txt").read_text(), "do not overwrite")

    def test_integrity_rejects_tamper(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as name:
            root = Path(name)
            data = root / "data.csv"
            data.write_text("old", encoding="utf-8")
            manifest = {"files": [{"path": "data.csv", "sha256": reproduce.file_hash(data), "bytes": 3}]}
            (root / "MANIFEST.json").write_text(json.dumps(manifest), encoding="utf-8")
            data.write_text("new", encoding="utf-8")
            with self.assertRaises(ValueError):
                reproduce.verify_package(root)

    def test_sign_flip_kernel(self):
        module = reproduce.analyzer("analyze_old_v2_main_comparison")
        self.assertEqual(module.sign_flip_p([1.0, 1.0]), 0.5)
        self.assertEqual(module.sign_flip_p([1.0, -1.0]), 1.0)
        self.assertEqual(module.holm([0.01, 0.04, 0.03]), [0.03, 0.06, 0.06])

    def test_bootstrap_is_deterministic(self):
        module = reproduce.analyzer("analyze_old_v2_main_comparison")
        self.assertEqual(module.bootstrap_ci([1, 2, 3], 1000), module.bootstrap_ci([1, 2, 3], 1000))

    def test_objective_grid_rejects_duplicate_and_wrong_budget(self):
        import pandas as pd

        module = reproduce.analyzer("analyze_shared_framework_models")
        data = pd.concat([pd.read_csv(p) for p in sorted((ROOT / "source_data/frozen").glob("shared_framework_models_*.csv"))])
        self.assertEqual(len(module.validate(data)), 180)
        with self.assertRaises(ValueError):
            module.validate(pd.concat([data, data.iloc[[0]]]))
        changed = data.copy().reset_index(drop=True)
        changed.loc[0, "iterMax"] = 301
        with self.assertRaises(ValueError):
            module.validate(changed)


if __name__ == "__main__":
    unittest.main()
