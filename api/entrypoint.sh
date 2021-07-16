#!/bin/bash

# Define some colors for the output.
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if ! spawnctl get data-images > /dev/null 2>&1 ; then
  echo -e "$RED You must authenticate to the Spawn service before using this preview environment $NC"
  echo ''
  echo -e "$RED Open the URL presented below and follow the instructions to authenticate $NC"
  echo ''

  if ! spawnctl auth ; then
    echo -e "$RED Unexpected error authenticating to Spawn $NC"
    echo -e "$RED Please restart the preview"
    exit 1
  fi
fi

source .env
source spawn.sh

validateImagesExist
setupContainers
migrateDatabases

echo 'Environment set up successfully!'

exec dotnet Spawn.Demo.WebApi.dll
