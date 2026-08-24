#include "logicsynth/netlist.hpp"

#include <iostream>

int main() {
  logicsynth::Module module;
  module.ports = {{"a", {2}}, {"b", {3}}, {"y", {5}}};
  module.cells["and0"] = {"and0", "$and", {{"A", {2}}, {"B", {3}}, {"Y", {4}}}};
  module.cells["and1"] = {"and1", "$and", {{"A", {2}}, {"B", {3}}, {"Y", {5}}}};
  auto report = logicsynth::optimize(module, logicsynth::Profile::named("balanced"));
  std::cout << "rewrites=" << report.rewrites
            << " area_proxy=" << report.metrics.area_proxy
            << " max_depth=" << report.metrics.max_depth << "\n";
  return 0;
}
