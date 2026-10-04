APP := dist/HeatPeek.app

.PHONY: all build app run once json test unit selftest selftest-full clean

all: build

build:
	swift build -c release

app: build
	scripts/make-app.sh

run: app
	open $(APP)

once: build
	.build/release/heatpeek --once

json: build
	.build/release/heatpeek --once --json

test: unit selftest

unit:
	swift test

selftest: build
	scripts/selftest.sh .build/release/heatpeek

selftest-full: build
	scripts/selftest.sh .build/release/heatpeek --full

clean:
	rm -rf .build dist
