#include "logicsynth/netlist.hpp"

#include <algorithm>
#include <deque>
#include <set>
#include <stdexcept>
#include <unordered_map>

namespace logicsynth {
namespace {

bool is_logic(const std::string &type) {
  static const std::set<std::string> types = {
      "$and", "$or", "$xor", "$xnor", "$not", "$mux", "$_AND_", "$_OR_"};
  return types.count(type) != 0;
}

std::vector<int> *output(Cell &cell) {
  for (const auto &port : {"Y", "Q", "out"}) {
    auto it = cell.connections.find(port);
    if (it != cell.connections.end()) return &it->second;
  }
  return nullptr;
}

std::string signature(const Cell &cell) {
  std::string result = cell.type;
  for (const auto &entry : cell.connections) {
    if (entry.first == "Y" || entry.first == "Q" || entry.first == "out")
      continue;
    result += "|" + entry.first + ":";
    for (int bit : entry.second) result += std::to_string(bit) + ",";
  }
  return result;
}

}  // namespace

Profile Profile::named(const std::string &name) {
  if (name == "balanced") return {};
  if (name == "area") return {2.0, 0.5, 0.5};
  if (name == "timing") return {0.5, 2.0, 0.5};
  if (name == "power") return {0.5, 0.5, 2.0};
  throw std::invalid_argument("unknown profile: " + name);
}

Metrics analyze(const Module &module) {
  Metrics metrics;
  metrics.cells = module.cells.size();
  std::map<int, std::string> drivers;
  std::map<std::string, std::set<std::string>> edges;
  std::map<std::string, std::size_t> indegree;
  std::map<std::string, std::size_t> depth;
  for (const auto &entry : module.cells) {
    indegree[entry.first] = 0;
    for (const auto &port : entry.second.connections)
      for (int bit : port.second) drivers.emplace(bit, entry.first);
    if (is_logic(entry.second.type)) ++metrics.logic_cells;
  }
  for (const auto &entry : module.cells) {
    for (const auto &port : entry.second.connections) {
      for (int bit : port.second) {
        auto driver = drivers.find(bit);
        if (driver != drivers.end() && driver->second != entry.first &&
            edges[driver->second].insert(entry.first).second)
          ++indegree[entry.first];
      }
    }
  }
  std::deque<std::string> ready;
  for (const auto &entry : indegree)
    if (entry.second == 0) ready.push_back(entry.first);
  while (!ready.empty()) {
    auto source = ready.front();
    ready.pop_front();
    for (const auto &target : edges[source]) {
      depth[target] = std::max(depth[target], depth[source] + 1);
      if (--indegree[target] == 0) ready.push_back(target);
    }
  }
  for (const auto &entry : edges) {
    metrics.edges += entry.second.size();
    metrics.fanout_max = std::max(metrics.fanout_max, entry.second.size());
  }
  for (const auto &entry : depth) metrics.max_depth = std::max(metrics.max_depth, entry.second);
  metrics.area_proxy = metrics.logic_cells;
  for (const auto &entry : module.cells)
    metrics.power_proxy += (edges[entry.first].size() + 1) *
                           (depth[entry.first] + 1);
  return metrics;
}

Report optimize(Module &module, const Profile &, std::size_t max_rewrites) {
  std::map<std::string, std::string> canonical;
  std::map<int, int> replacements;
  Report report;
  for (auto it = module.cells.begin(); it != module.cells.end() &&
                                     report.rewrites < max_rewrites;) {
    Cell &cell = it->second;
    if (!is_logic(cell.type)) {
      ++it;
      continue;
    }
    const auto key = signature(cell);
    auto prior = canonical.find(key);
    if (prior == canonical.end()) {
      canonical.emplace(key, it->first);
      ++it;
      continue;
    }
    auto *old_output = output(cell);
    auto *new_output = output(module.cells.at(prior->second));
    if (old_output != nullptr && new_output != nullptr &&
        old_output->size() == new_output->size()) {
      for (std::size_t i = 0; i < old_output->size(); ++i)
        replacements[(*old_output)[i]] = (*new_output)[i];
      it = module.cells.erase(it);
      ++report.rewrites;
    } else {
      ++it;
    }
  }
  for (auto &entry : module.cells)
    for (auto &port : entry.second.connections)
      for (int &bit : port.second)
        if (replacements.count(bit)) bit = replacements[bit];
  for (auto &entry : module.ports)
    for (int &bit : entry.second)
      if (replacements.count(bit)) bit = replacements[bit];
  for (auto &entry : module.netnames)
    for (int &bit : entry.second)
      if (replacements.count(bit)) bit = replacements[bit];
  report.metrics = analyze(module);
  return report;
}

}  // namespace logicsynth
