"""Small repository checks; no third-party source or assets are inspected."""

from pathlib import Path
import os
import re


EXCLUDED = {".git", ".tools", "__pycache__"}


def project_files(root):
    files = []
    for directory, children, names in os.walk(root):
        children[:] = [name for name in children if name not in EXCLUDED]
        files.extend(Path(directory) / name for name in names)
    return sorted(files)


def find_addon(root):
    candidates = [root / "CarGO_Orbit.toc", root / "CarGO_Orbit" / "CarGO_Orbit.toc"]
    found = [path for path in candidates if path.is_file()]
    if len(found) != 1:
        raise AssertionError("Expected exactly one CarGO_Orbit.toc")
    return found[0]


def toc_files(toc):
    return [line.strip().replace("\\", "/") for line in toc.read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.lstrip().startswith("#")]


def without_lua_comments_and_strings(source):
    # Sufficient for the deliberately small bootstrap source: preserve newlines
    # so a failed boundary check can still identify its source line.
    pattern = r"--\[\[.*?\]\]|--[^\n]*|\[\[.*?\]\]|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"
    return re.sub(pattern, lambda match: "\n" * match.group(0).count("\n"), source, flags=re.S)


def run(root):
    root = Path(root).resolve()
    files = project_files(root)
    toc = find_addon(root)
    addon = toc.parent
    entries = toc_files(toc)
    assert entries, "TOC has no load entries"
    assert len(entries) == len(set(entries)), "Duplicate TOC load entries"
    for entry in entries:
        path = (addon / entry).resolve()
        assert path.is_relative_to(addon.resolve()), "TOC path escapes addon directory"
        assert path.is_file(), "Missing TOC file: " + entry
        assert path.suffix == ".lua", "Unexpected TOC payload: " + entry

    metadata = dict(re.findall(r"^##\s*([^:]+):\s*(.+)$", toc.read_text(encoding="utf-8-sig"), re.M))
    expected = {
        "Interface": "120100", "Title": "CarGO Orbit", "Version": "0.0.1-dev",
        "RequiredDeps": "EllesmereUI", "SavedVariables": "CarGOOrbitDB", "Author": "TomXingCan",
        "Notes": "Combat and information extensions for EllesmereUI.",
    }
    for key, value in expected.items():
        assert metadata.get(key) == value, "TOC metadata mismatch: " + key

    def before(first, second):
        assert first in entries and second in entries, "Missing required TOC entry"
        assert entries.index(first) < entries.index(second), first + " must load before " + second

    before("Core/Addon.lua", "Config/Defaults.lua")
    before("Config/Defaults.lua", "Core/Database.lua")
    before("Core/Addon.lua", "Core/EUIAdapter.lua")
    before("Core/EUIAdapter.lua", "UI/Skin.lua")
    before("UI/Skin.lua", "UI/DebugPanel.lua")
    assert entries[-1] == "Core/Events.lua", "Lifecycle events must load after all registrations"
    addon_lua = {path.relative_to(addon).as_posix() for path in addon.rglob("*.lua")
                 if "tests" not in path.relative_to(addon).parts
                 and not any(part in EXCLUDED for part in path.relative_to(addon).parts)}
    assert addon_lua == set(entries), "Lua files and TOC entries differ"

    text_files = []
    for path in files:
        raw = path.read_bytes()
        assert b"\x00" not in raw, "Binary payload is not allowed: " + str(path.relative_to(root))
        try:
            text_files.append((path, raw.decode("utf-8-sig")))
        except UnicodeDecodeError as error:
            raise AssertionError("Non-text payload: " + str(path.relative_to(root))) from error
        assert path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".tga", ".blp", ".ttf", ".otf", ".mp3", ".ogg", ".wav", ".zip"}, "Unexpected bundled asset"

    forbidden = ["_" + "ModuleNS", "_" + "ERB_", "collect" + "garbage"]
    counts = {token: sum(source.count(token) for _, source in text_files) for token in forbidden}
    for token, count in counts.items():
        assert count == 0, "Forbidden token found: " + token + " (" + str(count) + ")"

    for entry in entries:
        path = addon / entry
        source = path.read_text(encoding="utf-8-sig")
        code = without_lua_comments_and_strings(source)
        assert "EllesmereUI" + "DB" not in source, "Direct third-party database access"
        if entry != "Core/EUIAdapter.lua":
            assert not re.search(r"\bEllesmereUI\b", code), "EUI boundary violation in " + entry
            assert not re.search(r"_G\s*\[\s*['\"]EllesmereUI['\"]", source), "Indirect EUI boundary violation"
        assert not re.search(r"\bEllesmereUI\s*\.\s*\w+\s*=", code), "Third-party function mutation"
        assert not re.search(r"SetScript\s*\(\s*['\"]OnUpdate['\"]\s*,\s*(?!nil\b)", source), "Persistent frame polling"
        assert not re.search(r"\bhooksecurefunc\s*\(", code), "Unexpected third-party hook"

    required = ["README.md", "CHANGELOG.md", "NOTICE.md", "LICENSE", ".gitignore"]
    for name in required:
        assert (root / name).is_file(), "Missing project document: " + name
    for name in ["ARCHITECTURE.md", "ROADMAP.md", "INFOBAR_SPEC.md", "ENHANCED_RESOURCE_BARS_SPEC.md"]:
        assert (root / "docs" / name).is_file(), "Missing design document: " + name
    return {"toc": toc, "lua_files": [addon / entry for entry in entries], "counts": counts, "files": len(files)}


if __name__ == "__main__":
    result = run(Path(__file__).resolve().parents[1])
    print("Static checks passed:", result["files"], "text files;", len(result["lua_files"]), "TOC entries")
    for token, count in result["counts"].items():
        print(token + ": " + str(count))
