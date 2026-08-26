#include "logicsynth/netlist.hpp"

#include <cassert>

int main() {
  logicsynth::Module module;
  module.ports = {{"a", {2}}, {"b", {3}}, {"y", {5}}};
  module.cells["and0"] = {"and0", "$and", {{"A", {2}}, {"B", {3}}, {"Y", {4}}}};
  module.cells["and1"] = {"and1", "$and", {{"A", {2}}, {"B", {3}}, {"Y", {5}}}};
  auto before = logicsynth::analyze(module);
  assert(before.logic_cells == 2);
  auto report = logicsynth::optimize(module, logicsynth::Profile::named("balanced"));
  assert(report.rewrites == 1);
  assert(module.cells.size() == 1);
  assert(module.ports["y"][0] == 4);
  assert(report.metrics.area_proxy == 1);
  assert(report.objective_after < report.objective_before);
}
