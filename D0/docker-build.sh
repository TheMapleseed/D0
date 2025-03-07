#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check last command status
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1 failed${NC}"
        exit 1
    fi
}

# Build Docker images
echo -e "${GREEN}Building Docker images...${NC}"
docker-compose build
check_status "Docker build"

# Run builder
echo -e "${GREEN}Running builder...${NC}"
docker-compose run --rm builder
check_status "Builder execution"

# Run tests
echo -e "${GREEN}Running tests...${NC}"
docker-compose run --rm tester
check_status "Tests execution"

echo -e "${GREEN}Build completed successfully${NC}" 