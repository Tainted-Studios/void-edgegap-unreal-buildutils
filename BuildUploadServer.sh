#!/bin/bash

# edit these values
github_pat='<GITHUB_PERSONAL_ACCESS_TOKEN>';
github_username='<GITHUB_USERNAME>';

ue_image_tag='dev-5.5.4';
server_config='Development';
project_file_name='LyraStarterGame';

registry='registry2.edgegap.com';
project='<REGISTRY_PROJECT>';
username='robot$<REGISTRY_ORGANIZATION_ID>+client-push';
token='<REGISTRY_TOKEN>';

# leave the rest of the script unchanged
if jqxxx --help 2>&1 | grep -Eq "not recognized|could not be found"; then
    echo "'jq' is not installed. Installing with apt-get...";
    sudo apt-get update;
    sudo apt-get install -y jq;
    if [ $? -ne 0 ]; then
        echo "Failed to install jq. Please install jq manually and rerun the script.";
        read -p "Press Enter to exit";
        exit 1;
    fi
fi

build_utils_path=$(pwd);
cd ..

if docker ps 2>&1 | grep -Eq "not recognized|could not be found"; then
    echo "Docker not installed or not running, visit https://www.docker.com";
    read -p "Press Enter to exit";
    exit 1;
fi

metadata_file_path="$build_utils_path/package.json"

if [ ! -f "$metadata_file_path" ]; then
    echo "Couldn't find package.json, re-download latest version from https://github.com/edgegap/edgegap-unreal-buildutils";
    read -p "Press Enter to exit";
    exit 1;
fi

local_version=$(jq -r '.version // empty' "$metadata_file_path");

if [ -z "$local_version" ]; then
    echo "Error reading or parsing local package.json: Version not found.";
    read -p "Press Enter to exit";
    exit 1;
fi

response=$( \
    curl -s \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "User-Agent: Bash" \
        --max-time 30 \
        "https://api.github.com/repos/edgegap/edgegap-unreal-buildutils/releases/latest"
);

latest_version=$(echo "$response" | jq -r '.name // empty');

if [ -z "$latest_version" ]; then
    echo "Error fetching release information or latest version not found.";
    read -p "Press Enter to exit";
    exit 1;
fi

if [ "$local_version" != "$latest_version" ] \
   && [ "$(printf '%s\n' "$local_version" "$latest_version" | sort -V | head -n1)" = "$local_version" ]; then
    echo "Update now - new buildutils version is available at https://github.com/edgegap/edgegap-unreal-buildutils"
fi

login_output=$(echo "$github_pat" | docker login ghcr.io -u "$github_username" --password-stdin 2>&1);
login_code=$?;

if echo "$login_output" | grep -q "unauthorized"; then
    echo "Docker GHCR login failed: unauthorized. Please verify your PAT.";
    read -p "Press Enter to exit";
    exit 1;
fi

if [ $login_code -ne 0 ]; then
    echo "Docker GHCR login failed: $login_output";
    read -p "Press Enter to exit";
    exit $login_code;
fi

echo "Docker GHCR login succeeded!";

docker pull "ghcr.io/epicgames/unreal-engine:$ue_image_tag";

image=$(basename "$PWD" | tr -d '\n' | sed 's/[[:space:]]\+/-/g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g');
tag=$(date +%y.%m.%d-%H.%M.%S-%Z);

login_output=$(echo "$token" | docker login "$registry" -u "$username" --password-stdin 2>&1);
login_code=$?;

if echo "$login_output" | grep -q "unauthorized"; then
    echo "Docker $registry login failed: unauthorized. Please verify your docker credentials.";
    read -p "Press Enter to exit";
    exit 1;
fi

if [ $login_code -ne 0 ]; then
    echo "Docker $registry login failed: $login_output";
    read -p "Press Enter to exit";
    exit $login_code;
fi

echo "Docker $registry login succeeded!";

docker build . \
    -t "${registry}/${project}/${image}:${tag}" \
    --build-arg UE_IMAGE_TAG=$ue_image_tag \
    --build-arg SERVER_CONFIG=$server_config \
    --build-arg PROJECT_FILE_NAME=$project_file_name;

docker push "${registry}/${project}/${image}:${tag}";

open "https://app.edgegap.com/application-management/applications/${image}/versions/create?name=${tag}&imageRepo=${project}/${image}&dockerTag=${tag}&vCPU=1&memory=1";

read -p "Press Enter to exit";
exit 1;