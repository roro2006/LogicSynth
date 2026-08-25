.PHONY: build test yosys-test benchmark clean

build:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
	cmake --build build --parallel

test: build
	ctest --test-dir build --output-on-failure
	PYTHONPATH=src python3 -m pytest -q

yosys-test:
	bash tests/integration_yosys.sh

benchmark:
	PYTHONPATH=src python3 scripts/benchmark.py tests/data results/latest.json

clean:
	rm -rf build
