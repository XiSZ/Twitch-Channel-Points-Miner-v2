#!/usr/bin/env python3
"""
Pickle File Viewer

A utility script to safely view and inspect the contents of pickle files,
particularly useful for examining cookie files and other serialized data.

Security Warning: Only load pickle files from trusted sources as they can
execute arbitrary code during deserialization.
"""

import argparse
import json
import pickle
import sys
from pathlib import Path
from typing import Any


def load_pickle_file(file_path: Path) -> Any:
    """
    Load and return the contents of a pickle file.

    Args:
        file_path: Path to the pickle file

    Returns:
        The deserialized object from the pickle file

    Raises:
        FileNotFoundError: If the file doesn't exist
        pickle.UnpicklingError: If the file is not a valid pickle file
        PermissionError: If there are insufficient permissions to read the file
    """
    try:
        with open(file_path, 'rb') as file:
            return pickle.load(file)
    except FileNotFoundError as exc:
        raise FileNotFoundError(f"File not found: {file_path}") from exc
    except pickle.UnpicklingError as exc:
        raise pickle.UnpicklingError(f"Invalid pickle file: {exc}") from exc
    except PermissionError as exc:
        raise PermissionError(
            f"Permission denied reading file: {file_path}"
        ) from exc


def format_output(data: Any, format_type: str = "pretty") -> str:
    """
    Format the data for display based on the specified format type.

    Args:
        data: The data to format
        format_type: Output format ('pretty', 'json', 'raw')

    Returns:
        Formatted string representation of the data
    """
    if format_type == "json":
        try:
            # Convert to JSON if possible
            return json.dumps(data, indent=2, default=str, ensure_ascii=False)
        except (TypeError, ValueError):
            # Fallback to pretty print if JSON serialization fails
            format_type = "pretty"

    if format_type == "pretty":
        import pprint
        return pprint.pformat(data, width=100, depth=None)

    # Raw format
    return str(data)


def print_file_info(file_path: Path) -> None:
    """Print basic information about the pickle file."""
    try:
        stat = file_path.stat()
        print(f"File: {file_path}")
        print(f"Size: {stat.st_size} bytes")
        print(f"Modified: {stat.st_mtime}")
        print("-" * 50)
    except OSError as e:
        print(f"Warning: Could not get file info: {e}")


def main() -> None:
    """Main function to handle command line arguments and process."""
    parser = argparse.ArgumentParser(
        description="View contents of pickle files (especially cookie files)"
    )
    parser.add_argument(
        "file",
        type=Path,
        help="Path to the pickle file to examine (e.g., cookies/user.pkl)"
    )
    parser.add_argument(
        "-f", "--format",
        choices=["pretty", "json", "raw"],
        default="pretty",
        help="Output format (default: pretty)"
    )
    parser.add_argument(
        "-i", "--info",
        action="store_true",
        help="Show file information before content"
    )
    parser.add_argument(
        "--no-warning",
        action="store_true",
        help="Suppress security warning about pickle files"
    )

    args = parser.parse_args()

    # Security warning
    if not args.no_warning:
        print("⚠️  Security Warning: Only load pickle files from trusted "
              "sources!")
        print("   Pickle files can execute arbitrary code during loading.\n")

    try:
        # Show command-line arguments used
        print("Arguments used:")
        print(f"  File: {args.file}")
        print(f"  Format: {args.format}")
        print(f"  Show info: {args.info}")
        print(f"  No warning: {args.no_warning}")
        print("-" * 50)

        # Show file info if requested
        if args.info:
            print_file_info(args.file)

        # Load and display the pickle file contents
        data = load_pickle_file(args.file)

        # Format and print the output
        formatted_output = format_output(data, args.format)
        print(formatted_output)

        # Show data type info
        print(f"\nData type: {type(data).__name__}")
        if isinstance(data, (list, dict, tuple, set)):
            print(f"Length: {len(data)}")

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        print("Please check the file path and try again.", file=sys.stderr)
        sys.exit(1)
    except pickle.UnpicklingError as e:
        print(f"Error: {e}", file=sys.stderr)
        print("The file may be corrupted or not a valid pickle file.",
              file=sys.stderr)
        sys.exit(1)
    except PermissionError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except (OSError, IOError) as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
