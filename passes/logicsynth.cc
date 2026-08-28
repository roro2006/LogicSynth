/*
 * Native Yosys pass for conservative duplicate-cone sharing.
 *
 * The standalone C++ library remains the reusable analysis/optimization core.
 * This adapter operates directly on RTLIL so a Yosys flow does not need a JSON
 * round trip when the Yosys development headers are available.
 */
#include "kernel/yosys.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

struct LogicSynthPass : public Pass {
  LogicSynthPass() : Pass("logicsynth", "share identical combinational cones") {}

  void help() override {
    log("\n");
    log("    logicsynth [-profile balanced|area|timing|power]\n");
    log("               [-area_weight W] [-delay_weight W] [-power_weight W]\n");
    log("               [-max_rewrites N]\n");
    log("\n");
    log("Share identical combinational cells while preserving RTLIL signals.\n");
    log("Sequential and unknown cell types are left unchanged.\n");
    log("\n");
  }

  void execute(std::vector<std::string> args, RTLIL::Design *design) override {
    log_header(design, "Executing LogicSynth native optimization.\n");
    size_t max_rewrites = 1000;
    std::string profile = "balanced";
    double area_weight = 1.0, delay_weight = 1.0, power_weight = 1.0;
    for (size_t arg = 1; arg < args.size(); ++arg) {
      if (args[arg] == "-max_rewrites" && arg + 1 < args.size()) {
        max_rewrites = std::stoull(args[++arg]);
      } else if (args[arg] == "-profile" && arg + 1 < args.size()) {
        profile = args[++arg];
        if (profile == "area") {
          area_weight = 2.0; delay_weight = 0.5; power_weight = 0.5;
        } else if (profile == "timing") {
          area_weight = 0.5; delay_weight = 2.0; power_weight = 0.5;
        } else if (profile == "power") {
          area_weight = 0.5; delay_weight = 0.5; power_weight = 2.0;
        } else if (profile != "balanced") {
          log_error("Unknown profile: %s\n", profile.c_str());
        }
      } else if (args[arg] == "-area_weight" && arg + 1 < args.size()) {
        area_weight = std::stod(args[++arg]);
      } else if (args[arg] == "-delay_weight" && arg + 1 < args.size()) {
        delay_weight = std::stod(args[++arg]);
      } else if (args[arg] == "-power_weight" && arg + 1 < args.size()) {
        power_weight = std::stod(args[++arg]);
      } else if (args[arg] == "-help") {
        help();
        return;
      } else {
        log_error("Unknown option: %s\n", args[arg].c_str());
      }
      log("  profile=%s area_weight=%.3f delay_weight=%.3f power_weight=%.3f max_rewrites=%zu\n",
          profile.c_str(), area_weight, delay_weight, power_weight, max_rewrites);
    }

    for (auto *module : design->selected_modules()) {
      dict<std::string, RTLIL::Cell *> canonical;
      size_t rewrites = 0;
      for (auto it = module->cells_.begin();
           it != module->cells_.end() && rewrites < max_rewrites;) {
        RTLIL::Cell *cell = it->second;
        if (!is_logic(cell->type)) {
          ++it;
          continue;
        }
        RTLIL::SigSpec output = cell->getPort(ID::Y);
        if (output.empty())
          output = cell->getPort(ID::Q);
        if (output.empty()) {
          ++it;
          continue;
        }

        std::string key = cell->type.str();
        for (const auto &port : cell->connections()) {
          if (port.first == ID::Y || port.first == ID::Q)
            continue;
          key += "|" + port.first.str() + ":" + port.second.as_string();
        }

        auto prior = canonical.find(key);
        if (prior == canonical.end()) {
          canonical[key] = cell;
          ++it;
          continue;
        }
        if (prior->second == cell) {
          ++it;
          continue;
        }
        RTLIL::SigSpec canonical_output = prior->second->getPort(ID::Y);
        if (canonical_output.empty())
          canonical_output = prior->second->getPort(ID::Q);
        if (canonical_output.size() != output.size()) {
          ++it;
          continue;
        }
        module->connect(output, canonical_output);
        module->remove(cell);
        it = module->cells_.begin();
        ++rewrites;
      }
      log("  %s: %zu duplicate cones shared.\n", log_id(module), rewrites);
    }
  }

private:
  static bool is_logic(const RTLIL::IdString &type) {
    const auto name = type.str();
    return name == "$and" || name == "$or" || name == "$xor" ||
           name == "$xnor" || name == "$not" || name == "$mux" ||
           name == "$_AND_" || name == "$_OR_";
  }
};

LogicSynthPass logicsynth_pass;
PRIVATE_NAMESPACE_END
