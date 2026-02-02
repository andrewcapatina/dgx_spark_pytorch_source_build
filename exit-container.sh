#!/bin/bash
# Exit the Docker container
# This script can be used inside the container or to stop containers from outside

# Check if we're inside a Docker container
if [ -f /.dockerenv ]; then
    echo "Exiting Docker container..."
    exit 0
else
    # We're outside the container, stop any running pytorch containers
    echo "Stopping PyTorch Docker containers..."

    CONTAINERS=$(docker ps -q --filter "ancestor=pytorch-cuda13.0-dgx")

    if [ -z "$CONTAINERS" ]; then
        echo "No running PyTorch containers found."
    else
        docker stop $CONTAINERS
        echo "Containers stopped."
    fi
fi
