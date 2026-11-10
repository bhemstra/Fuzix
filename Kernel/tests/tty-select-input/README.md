# tty-select-input regression checks

Run `python3 Kernel/tests/tty-select-input/check.py` from the repository root.
Requires Python 3 and a C compiler with ASan/UBSan. The runner extracts actual
production function bodies, reads kernel constants/headers, and mocks surrounding
interfaces. Each case runs in a fresh process. Use `--kernel-dir /path/Kernel`
to check another checkout. These are host checks, not hardware tests.
