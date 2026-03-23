"""CLI tool to count words, lines, and characters in a file."""
import argparse
import sys


def count_file(filepath: str) -> tuple[int, int, int]:
    """Return (lines, words, chars) for the given file."""
    with open(filepath) as f:
        content = f.read()
    lines = content.count("\n") + (1 if content and not content.endswith("\n") else 0)
    words = len(content.split())
    chars = len(content)
    return lines, words, chars


def main() -> int:
    parser = argparse.ArgumentParser(description="Count words, lines, and characters in a file.")
    parser.add_argument("file", help="Path to the file to count")
    args = parser.parse_args()

    try:
        lines, words, chars = count_file(args.file)
    except (FileNotFoundError, PermissionError, IsADirectoryError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    print(f"Lines: {lines}")
    print(f"Words: {words}")
    print(f"Characters: {chars}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
