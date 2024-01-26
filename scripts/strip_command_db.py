#!/usr/bin/python3
import argparse
import json
import os


def main():
    db_location = "~/projects/as-houyi/compile_commands.json"

    parser = argparse.ArgumentParser(description='Strip the compile_commands.json file to improve performance.')
    parser.add_argument('-i', metavar="compile_commands.json", default=db_location,
                        help="The compile_commands.json file location")
    parser.add_argument('-o', metavar="output_compiledb name", default=db_location, help="The output file")

    args = parser.parse_args()
    args.i = os.path.relpath(os.path.expandvars(os.path.expanduser(args.i)))
    args.o = os.path.relpath(os.path.expandvars(os.path.expanduser(args.o)))

    with open(args.i) as db:
        json_db = json.load(db)

        # filter out the redundant entries
        # 1. remove the object that file field is duplicated

        remove_dup = list({entry['file']: entry for entry in json_db}.values())

        # 2. remove entries by the custom filter
        filtered_json = list(filter(item_filter, remove_dup))

        # nothing need to save back if nothing filtered.
        if len(json_db) == len(filtered_json):
            print("Total %d entries in file %s, nothing filter out " % (len(json_db), args.i))
            return

        # write to output
        print("Total %s entries in %s, remains %s entries after filtered" % (len(json_db), args.i, len(filtered_json)))
        with open(args.o, "w") as out:
            json.dump(filtered_json, out, indent=2)


def item_filter(entry):
    # condition to filter file out
    file = entry['file']
    cond = any((
        # entry['file'].startswith('external/') and ('opencv' not in entry['file']),
        not (file.endswith('.cc') or (file.endswith('.cpp'))),
        file.startswith('bazel-out/'),
        file.startswith('external/zlib/'),
        '.so' in file,
    ))

    return not cond


if __name__ == "__main__":
    main()
