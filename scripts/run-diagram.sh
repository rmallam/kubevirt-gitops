#!/bin/bash

# Set up Python environment and run diagram script

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install required packages
echo "Installing dependencies..."
pip install diagrams graphviz

# Run the diagram script
echo "Generating diagram..."
python rsync-dr-architecture.py

# Check if diagram was created
if [ -f "fedora_vm_with_efs_dr_architecture.png" ]; then
    echo "Diagram created successfully: fedora_vm_with_efs_dr_architecture.png"
    
    # Open the diagram if on macOS
    if [ "$(uname)" == "Darwin" ]; then
        open fedora_vm_with_efs_dr_architecture.png
    fi
else
    echo "Failed to generate diagram"
fi

echo "Done!"
