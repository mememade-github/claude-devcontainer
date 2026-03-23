import os
import subprocess
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run_wordcount(filepath):
    """Helper to run wordcount.py as CLI and return result."""
    result = subprocess.run(
        [sys.executable, os.path.join(PROJECT_ROOT, "src", "wordcount.py"), filepath],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )
    return result


def parse_output(stdout):
    """Parse structured output into a dict."""
    result = {}
    for line in stdout.strip().splitlines():
        key, value = line.split(": ", 1)
        result[key.strip()] = int(value.strip())
    return result


class TestWordCountNormalInput:
    def test_counts_words_lines_chars(self, tmp_path):
        f = tmp_path / "sample.txt"
        f.write_text("hello world\nfoo bar baz\n")
        result = run_wordcount(str(f))
        assert result.returncode == 0
        counts = parse_output(result.stdout)
        assert counts["Lines"] == 2
        assert counts["Words"] == 5
        assert counts["Characters"] == 24

    def test_single_line_no_newline(self, tmp_path):
        f = tmp_path / "single.txt"
        f.write_text("one two three")
        result = run_wordcount(str(f))
        assert result.returncode == 0
        counts = parse_output(result.stdout)
        assert counts["Lines"] == 1
        assert counts["Words"] == 3
        assert counts["Characters"] == 13


class TestWordCountFileNotFound:
    def test_nonexistent_file_returns_error(self):
        result = run_wordcount("/tmp/does_not_exist_12345.txt")
        assert result.returncode != 0
        assert "error" in result.stderr.lower()


class TestWordCountEmptyFile:
    def test_empty_file_returns_zeros(self, tmp_path):
        f = tmp_path / "empty.txt"
        f.write_text("")
        result = run_wordcount(str(f))
        assert result.returncode == 0
        counts = parse_output(result.stdout)
        assert counts["Lines"] == 0
        assert counts["Words"] == 0
        assert counts["Characters"] == 0
