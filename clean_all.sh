#!/bin/bash

# Confirmation prompt
read -p "Are you sure you want to stop and remove all Docker containers, and prune all unused images, networks, and volumes? (y/n): " confirm


# Check if user confirmed
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Stopping and removing all Docker containers..."
    docker stop $(docker ps -aq) 2>/dev/null
    docker rm $(docker ps -aq) 2>/dev/null

    echo "Pruning Docker system and volumes..."
    docker system prune -af
    docker volume prune -f

    echo "Operation completed."
else
    echo "Operation aborted."
fi

# Confirmation prompt
read -p "Are you sure you want clean repository? (y/n): " confirm_repo

# Check if user confirmed
if [[ "$confirm_repo" =~ ^[Yy]$ ]]; then
    echo "Removing repository..."
    rm -rf ./WGDashboard

    echo "Operation completed."
else
    echo "Operation aborted."
fi


