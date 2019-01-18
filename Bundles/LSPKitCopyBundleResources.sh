#!/bin/sh

# Use "Run Script Phase" instead of "Copy Files Phase"
# because Xcode indexes all folder references and we
# don't want node_modules to mix up our project index.

echo ditto "${SCRIPT_INPUT_FILE_0}" "${SCRIPT_OUTPUT_FILE_0}"
ditto "${SCRIPT_INPUT_FILE_0}" "${SCRIPT_OUTPUT_FILE_0}"
