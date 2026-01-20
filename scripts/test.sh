#!/bin/bash
set -e

# --- Producer Tests ---
echo "--- Running Producer Tests ---"
cd services/producer
# Install dependencies, including test dependencies
pip install -r requirements.txt
# Run tests
pytest
# Cleanup
cd ../..

# --- Processor Tests ---
echo "--- Running Processor Tests ---"
cd services/processor
# Install dependencies, including test dependencies
pip install -r requirements.txt
# Run tests
pytest
# Cleanup
cd ../..

echo "All tests passed successfully!"
