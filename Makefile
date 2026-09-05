.PHONY: build test yosys-test yosys-plugin yosys-plugin-test benchmark clean

YOSYS_CONFIG ?= yosys-config

build:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
	cmake --build build --parallel

test: build
	ctest --test-dir build --output-on-failure

yosys-test:
	bash tests/integration_yosys.sh

yosys-plugin:
	@test -n "$$(command -v $(YOSYS_CONFIG) 2>/dev/null)" || \
	  (echo "yosys-config is required; install the Yosys development package" >&2; exit 2)
	mkdir -p build
	$(CXX) $(shell $(YOSYS_CONFIG) --cxxflags) -std=c++17 -fPIC -shared \
	  -o build/logicsynth.so passes/logicsynth.cc $(shell $(YOSYS_CONFIG) --ldlibs)

yosys-plugin-test:
	bash tests/native_yosys_plugin.sh

benchmark:
	bash scripts/benchmark_native.sh tests/data/duplicate_cone.v

clean:
	rm -rf build
