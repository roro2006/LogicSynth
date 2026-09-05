.PHONY: build test yosys-test yosys-plugin yosys-plugin-test benchmark clean

build:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
	cmake --build build --parallel

test: build
	ctest --test-dir build --output-on-failure
	PYTHONPATH=src python3 -m pytest -q

yosys-test:
	bash tests/integration_yosys.sh

yosys-plugin:
	@test -n "$$(command -v yosys-config 2>/dev/null)" || \
	  (echo "yosys-config is required; install the Yosys development package" >&2; exit 2)
	mkdir -p build
	$$(CXX) -std=c++17 -fPIC -shared -o build/logicsynth.so \
	  passes/logicsynth.cc $$(yosys-config --cxxflags --ldlibs)

yosys-plugin-test:
	bash tests/native_yosys_plugin.sh

benchmark:
	PYTHONPATH=src python3 scripts/benchmark.py tests/data results/latest.json

clean:
	rm -rf build
