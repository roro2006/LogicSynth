import json

from logicsynth.metrics import analyze
from logicsynth.optimizer import Optimizer, Profile


def load_design():
    with open("tests/data/tiny.json") as handle:
        return json.load(handle)


def test_metrics_count_logic_and_depth():
    metrics = analyze(load_design()["modules"]["top"])
    assert metrics["logic_cells"] == 2
    assert metrics["area_proxy"] == 2
    assert metrics["max_depth"] == 1


def test_duplicate_cone_rewrite_preserves_output_wire():
    optimized, report = Optimizer(Profile.named("balanced")).optimize(load_design())
    assert report["modules"]["top"]["rewrites"] == 1
    assert len(optimized["modules"]["top"]["cells"]) == 1
    assert optimized["modules"]["top"]["ports"]["y"]["bits"] == [4]


def test_profile_override():
    profile = Profile.named("timing", area_weight=3.0)
    assert profile.area_weight == 3.0
    assert profile.delay_weight == 2.0
