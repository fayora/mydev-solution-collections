import argparse
import re
import json
import os

def parse_file(input_path):
    with open(input_path, 'r') as f:
        data = f.read()

    entries = re.findall(r'\[(.*?)\]', data)

    only_name = []
    only_key = []
    only_file = []

    for entry in entries:
        pairs = re.findall(r'"(.*?)":"(.*?)"', entry)
        keys = [k for k, _ in pairs]
        unique_keys = set(keys)

        if len(unique_keys) == 1:
            key = keys[0]
            values = [v for _, v in pairs]
            if key == "StorageAccountName":
                only_name.append(values)
            elif key == "StorageAccountKey":
                only_key.append(values)
            elif key == "FileshareName":
                only_file.append(values)

    return {
        "StorageAccountName": only_name,
        "StorageAccountKey": only_key,
        "FileshareName": only_file
    }

def main():
    parser = argparse.ArgumentParser(description="Filter entries by single key type")
    parser.add_argument('--input', required=True, help='Path to input file')
    parser.add_argument('--output', required=True, help='Path to output JSON file')

    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"Error: File '{args.input}' does not exist.")
        return

    result = parse_file(args.input)

    with open(args.output, 'w') as f:
        json.dump(result, f, indent=2)

    print(f"Filtered output written to {args.output}")

if __name__ == "__main__":
    main()