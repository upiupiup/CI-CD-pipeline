#!/bin/bash
# Run on Jenkins agent

echo "Running tests for CarVilla web application"

# Check if index.html exists
if [ ! -f index.html ]; then
  echo "Error: index.html not found!"
  exit 1
fi

# Check if critical directories exist
if [ ! -d assets ]; then
  echo "Error: assets directory not found!"
  exit 1
fi

# Check if critical JS and CSS files exist
if [ ! -f assets/js/jquery.js ]; then
  echo "Error: jQuery file not found!"
  exit 1
fi

if [ ! -f assets/css/style.css ]; then
  echo "Error: Main CSS file not found!"
  exit 1
fi

# Validate HTML syntax (if html5validator is available)
if command -v html5validator &> /dev/null; then
  html5validator --root .
  if [ $? -ne 0 ]; then
    echo "HTML validation failed!"
    exit 1
  fi
fi

echo "All tests passed successfully!"
exit 0