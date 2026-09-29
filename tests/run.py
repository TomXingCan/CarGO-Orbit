"""Run static checks, Lua 5.1 compilation, and isolated WoW API mock tests.

Run with Python 3.9+ and Lupa (its lua51 module). A local ignored installation
under .tools/python is supported; no package is loaded by the addon itself.
"""

from pathlib import Path
import sys

from static_scan import run


def main():
    root = Path(__file__).resolve().parents[1]
    result = run(root)
    print("PASS static checks (" + str(result["files"]) + " project text files)")
    for token, count in result["counts"].items():
        print("  " + token + ": " + str(count))
    local_packages = root / ".tools" / "python"
    if local_packages.is_dir():
        sys.path.insert(0, str(local_packages))
    try:
        from lupa.lua51 import LuaRuntime
    except ImportError as error:
        raise SystemExit("Lua 5.1 checks require Lupa's lua51 module in the Python environment.") from error
    lua = LuaRuntime(unpack_returned_tuples=True)
    assert lua.eval("_VERSION") == "Lua 5.1", "Tests must use Lua 5.1"
    compile_source = lua.eval("function(source, name) local fn, err = loadstring(source, name); return fn ~= nil, err end")
    sources = result["lua_files"] + [root / "tests" / "run.lua"]
    for path in sources:
        valid, error = compile_source(path.read_text(encoding="utf-8-sig"), "@" + path.as_posix())
        assert valid, error
    print("PASS Lua 5.1 syntax (" + str(len(sources)) + " files)")
    lua.globals().ADDON_ROOT = result["toc"].parent.as_posix()
    lua.globals().TOC_ENTRIES = lua.table_from([path.relative_to(result["toc"].parent).as_posix() for path in result["lua_files"]])
    lua.execute((root / "tests" / "run.lua").read_text(encoding="utf-8-sig"))


if __name__ == "__main__":
    main()
