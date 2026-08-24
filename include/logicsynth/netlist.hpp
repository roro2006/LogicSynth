#pragma once

#include <cstddef>
#include <map>
#include <string>
#include <vector>

namespace logicsynth {

struct Cell {
  std::string name;
  std::string type;
  std::map<std::string, std::vector<int>> connections;
};

struct Module {
  std::map<std::string, Cell> cells;
  std::map<std::string, std::vector<int>> ports;
  std::map<std::string, std::vector<int>> netnames;
};

struct Metrics {
  std::size_t cells = 0;
  std::size_t logic_cells = 0;
  std::size_t edges = 0;
  std::size_t max_depth = 0;
  std::size_t area_proxy = 0;
  std::size_t power_proxy = 0;
  std::size_t fanout_max = 0;
};

struct Profile {
  double area_weight = 1.0;
  double delay_weight = 1.0;
  double power_weight = 1.0;

  static Profile named(const std::string &name);
};

struct Report {
  std::size_t rewrites = 0;
  Metrics metrics;
};

Metrics analyze(const Module &module);
Report optimize(Module &module, const Profile &profile,
                std::size_t max_rewrites = 1000);

}  // namespace logicsynth
