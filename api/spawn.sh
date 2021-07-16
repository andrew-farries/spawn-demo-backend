#!/bin/bash

set -e

export PATH=$HOME/.spawnctl/bin:$PATH

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -z "$WDPR_COMMIT_HASH" ]; then
  accountDataContainerName="demo-account-$(cat /dev/random | LC_ALL=C tr -dc "[:alpha:]" | head -c 8)"
  todoDataContainerName="demo-todo-$(cat /dev/random | LC_ALL=C tr -dc "[:alpha:]" | head -c 8)"
else
  accountDataContainerName="demo-account-$WDPR_COMMIT_HASH"
  todoDataContainerName="demo-todo-$WDPR_COMMIT_HASH"
fi

function logSpawnMessage() {
    GREEN='\033[0;32m'
    NC='\033[0m'
    printf "🛸  ${GREEN}$1${NC}\n"
}

function validateImagesExist() {
    if [[ -z $SPAWN_TODO_IMAGE_NAME ]]; then
        logSpawnMessage "No spawn 'Todo' database image specified in environment variable SPAWN_TODO_IMAGE_NAME. Please specify an image id."
        exit 1
    fi

    if [[ -z $SPAWN_ACCOUNT_IMAGE_NAME ]]; then
        logSpawnMessage "No spawn 'Account' database image specified in environment variable SPAWN_ACCOUNT_IMAGE_NAME. Please specify an image id."
        exit 1
    fi

    if ! spawnctl get data-image $SPAWN_TODO_IMAGE_NAME &> /dev/null ; then
        logSpawnMessage "Could not find spawn image with id '$SPAWN_TODO_IMAGE_NAME'. Please ensure you have created the image."
        exit 1
    fi

    if ! spawnctl get data-image $SPAWN_ACCOUNT_IMAGE_NAME &> /dev/null ; then
        logSpawnMessage "Could not find spawn image with id '$SPAWN_ACCOUNT_IMAGE_NAME'. Please ensure you have created the image."
        exit 1
    fi
}

function setupContainers() {
    logSpawnMessage "Creating 'Todo' Spawn container from image '$SPAWN_TODO_IMAGE_NAME'"
    spawnctl create data-container --image $SPAWN_TODO_IMAGE_NAME --name "$todoDataContainerName" -q --lifetime 24h > /dev/null
    logSpawnMessage "Spawn 'Todo' container '$todoDataContainerName' created from image '$SPAWN_TODO_IMAGE_NAME'"

    echo

    logSpawnMessage "Creating 'Account' Spawn container from image '$SPAWN_ACCOUNT_IMAGE_NAME'"
    spawnctl create data-container --image $SPAWN_ACCOUNT_IMAGE_NAME --name "$accountDataContainerName" -q --lifetime 24h > /dev/null
    logSpawnMessage "Spawn 'Account' container '$accountDataContainerName' created from image '$SPAWN_ACCOUNT_IMAGE_NAME'"

    updateDatabaseAppSettings

    echo
    echo

    logSpawnMessage "Successfully provisioned Spawn containers. Ready to start app"
}

function migrateDatabases {
    todoDataContainerJson=$(spawnctl get data-container $todoDataContainerName -o json)
    accountDataContainerJson=$(spawnctl get data-container $accountDataContainerName -o json)

    todoPort=$(echo $todoDataContainerJson | jq -r .port)
    todoHost=$(echo $todoDataContainerJson | jq -r .host)
    todoUser=$(echo $todoDataContainerJson | jq -r .user)
    todoPassword=$(echo $todoDataContainerJson | jq -r .password)

    accountPort=$(echo $accountDataContainerJson | jq -r .port)
    accountHost=$(echo $accountDataContainerJson | jq -r .host)
    accountUser=$(echo $accountDataContainerJson | jq -r .user)
    accountPassword=$(echo $accountDataContainerJson | jq -r .password)

    $DIR/migrate-db.sh $accountHost $accountPort $accountUser $accountPassword $todoHost $todoPort $todoUser $todoPassword
}

function updateDatabaseAppSettings {
    appSettingsFilePath=./appsettings.Development.Database.json

    logSpawnMessage "Updating '$appSettingsFilePath' with data container connection strings"

    todoDataContainerJson=$(spawnctl get data-container $todoDataContainerName -o json)
    accountDataContainerJson=$(spawnctl get data-container $accountDataContainerName -o json)

    todoPort=$(echo $todoDataContainerJson | jq -r .port)
    todoHost=$(echo $todoDataContainerJson | jq -r .host)
    todoPassword=$(echo $todoDataContainerJson | jq -r .password)
    todoUser=$(echo $todoDataContainerJson | jq -r .user)

    accountPort=$(echo $accountDataContainerJson | jq -r .port)
    accountHost=$(echo $accountDataContainerJson | jq -r .host)
    accountPassword=$(echo $accountDataContainerJson | jq -r .password)
    accountUser=$(echo $accountDataContainerJson | jq -r .user)

    todoConnString="Host=$todoHost;Port=$todoPort;Database=spawndemotodo;User Id=$todoUser;Password=$todoPassword;"
    accountConnString="Server=$accountHost,$accountPort;Database=spawndemoaccount;User Id=$accountUser;Password=$accountPassword;"

    mkdir -p $DIR/src/Spawn.Demo.WebApi/
    jq -n "{\"TodoDatabaseConnectionString\": \"$todoConnString\", \"AccountDatabaseConnectionString\": \"$accountConnString\"}" > $appSettingsFilePath

    logSpawnMessage "'$appSettingsFilePath' successfully updated with data container connection string"
}