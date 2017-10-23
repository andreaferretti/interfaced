# Package

version       = "0.2.0"
author        = "Andrea Ferretti"
description   = "Go-like interfaces"
license       = "Apache2"
skipFiles     = @["test.nim", "test_exports.nim", "test_logsink.nim"]

# Dependencies

requires "nim >= 0.16.0"

task tests, "run tests":
  --hints: off
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "."
  --run
  setCommand "c", "test.nim"

task test, "run tests":
  setCommand "tests"