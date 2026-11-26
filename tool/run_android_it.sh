#!/usr/bin/env bash
# Runs inside the emulator runner; output is captured so CI can report it.
set +e
flutter test integration_test/export_test.dart -d emulator-5554 > it.txt 2>&1
echo $? > it.code
