import os
import re
import sys
import xml.etree.ElementTree as ET

def strip_lua_comments(code):
    # Remove multi-line comments
    code = re.sub(r'--\[\[.*?\]\]', '', code, flags=re.DOTALL)
    # Remove single-line comments
    code = re.sub(r'--.*$', '', code, flags=re.MULTILINE)
    # Remove polyfill declarations
    code = re.sub(r'function\s+IsInRaid\s*\(.*?\)', '', code)
    return code

def test_addon_sanity():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"Testing addon directory: {base_dir}")

    # 1. Verify required documentation files
    required_docs = [
        "README.md", "CHANGELOG.md", "LICENSE", "NOTICE.md",
        "API.md", "AGENTS.md", "INSTALL.md", "SECURITY.md",
        "ECOSYSTEM_REGISTRY.md", ".gitignore", ".gitattributes"
    ]
    for doc in required_docs:
        path = os.path.join(base_dir, doc)
        assert os.path.exists(path), f"Missing required file: {doc}"
    print("[PASS] All required repository documentation files exist.")

    # 2. Check Lua files for forbidden Retail APIs and deprecated/broken commands
    for root, dirs, files in os.walk(base_dir):
        if ".git" in root or "Tests" in root or "Libs" in root:
            continue
        for f in files:
            if f.endswith(".lua"):
                file_path = os.path.join(root, f)
                with open(file_path, "r", encoding="utf-8", errors="ignore") as lf:
                    raw_content = lf.read()
                    content = strip_lua_comments(raw_content)
                    assert not re.search(r'\bSetColorTexture\s*\(', content), f"Forbidden SetColorTexture found in {f}"
                    assert not re.search(r'\bC_Timer\.After\s*\(', content), f"Forbidden C_Timer.After found in {f}"
                    assert not re.search(r'(?<![:\.\w])IsInRaid\s*\(', content), f"Forbidden global IsInRaid found in {f}"
                    
                    # Command sanity check: no broken commands
                    assert not re.search(r'["\']\.group revive["\']', content), f"Nonexistent .group revive command found in {f}"
                    assert not re.search(r'["\']\.go object\b', content), f"Nonexistent .go object command found in {f} (use .go gameobject)"
                    assert not re.search(r'["\']\.gob (?:add|delete|del)\b', content), f"Nonexistent .gob command found in {f} (use .gobject)"
                    assert not re.search(r'["\']\.gobject del\b', content), f"Invalid .gobject del found in {f} (use .gobject delete)"
    print("[PASS] All Lua files adhere to 3.3.5a engine and AzerothCore command rules.")

    # 3. Check XML files for valid parsing
    for root, dirs, files in os.walk(base_dir):
        if ".git" in root or "Tests" in root or "Libs" in root:
            continue
        for f in files:
            if f.endswith(".xml"):
                xml_path = os.path.join(root, f)
                try:
                    ET.parse(xml_path)
                except ET.ParseError as e:
                    assert False, f"XML Parse error in {f}: {e}"
    print("[PASS] All XML files parse cleanly.")

    # 4. Check TOC file existence
    toc_path = os.path.join(base_dir, "ProjectJaina_GMGenie.toc")
    assert os.path.exists(toc_path), "ProjectJaina_GMGenie.toc missing!"
    print("[PASS] ProjectJaina_GMGenie.toc verified.")

    print("\n>>> ALL ProjectJaina_GMGenie SANITY CHECKS PASSED 100% <<<")

if __name__ == "__main__":
    test_addon_sanity()
