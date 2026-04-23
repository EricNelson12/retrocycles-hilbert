#!/bin/bash

# Navigate to the project directory
cd "$(dirname "$0")"

# Compile the Swift program
swiftc main.swift -o macos_shortcut_listener
if [ $? -ne 0 ]; then
  echo "Compilation failed. Please check your Swift code for errors."
  exit 1
fi

echo "Compilation successful."

# Prompt the user to grant Accessibility permissions
echo "Please ensure that Accessibility permissions are granted for this program."
echo "1. Open System Settings > Privacy & Security > Accessibility."
echo "2. Add the executable located at: $(pwd)/macos_shortcut_listener"
echo "3. Enable the checkbox next to it."

# Run the program
./macos_shortcut_listener
