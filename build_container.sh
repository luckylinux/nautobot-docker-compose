#!/bin/bash

#podman build --build-arg=NAUTOBOT_VERSION="stable" --build-arg=PYTHON_VER="3.11" --format docker ./environments/

#cd ./environments/ || exit
#podman build --build-arg=NAUTOBOT_VERSION="stable" --build-arg=PYTHON_VER="3.11" --format docker ../ -f Dockerfile


# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
libpath=$(readlink --canonicalize-missing "${toolpath}/includes")
source "${libpath}/functions.sh"

# Optional argument
engine=${1-"podman"}

# Check if Engine Exists
engine_exists "${engine}"
if [[ $? -ne 0 ]]
then
    # Error
    echo "[CRITICAL] Neither Podman nor Docker could be found and/or the specified Engine <${engine}> was not valid."
    echo "ABORTING !"
    exit 9
fi

# Load the Environment Variables into THIS Script
eval "$(shdotenv --env ${toolpath}/.env || echo \"exit $?\")"

# Run a Local Registry WITHOUT Persistent Data Storage
run_local_registry "${engine}"

# Image Name
name="nautobot-docker-compose"

# Options
# Use --no-cache when e.g. updating docker-entrypoint.sh and images don't get updated as they should
opts=()
opts+=("--build-arg")
opts+=("NAUTOBOT_VERSION=stable")
opts+=("--build-arg")
opts+=("PYTHON_VER=3.11")
opts+=("--format")
opts+=("docker")

#opts="--no-cache"

# Mandatory Tag
#tag=$(cat ./tag.txt)
tag=$(date +%Y%m%d)

# Select Platform
# Not used for now
#platform="linux/amd64"
#platform="linux/arm64/v8"


# Select Dockerfile
buildfile="Dockerfile"

# Check if they are set
if [[ ! -v name ]] || [[ ! -v tag ]]
then
   echo "Both Container Name and Tag Must be Set" !
fi

# Define Tags to attach to this image
imagetags=()
imagetags+=("${name}:${tag}")
imagetags+=("${name}:latest")


# Copy requirements into the build context
# cp <myfolder> . -r docker build . -t  project:latest


# For each image tag
tagargs=()
for imagetag in "${imagetags[@]}"
do
   # Echo
   echo "Processing Image Tag <${imagetag}> for Container Image <${name}>"

   # Check if Image with the same Name already exists
   remove_image_already_present "${imagetag}" "${engine}"

   # Add Argument to tag this Image too when running Container Build Command
   tagargs+=("-t")
   tagargs+=("${imagetag}")
done

# Build Container Image
#${engine} build ${opts} -f ${buildfile} . ${tagargs[*]}
#${engine} build --build-arg=NAUTOBOT_VERSION="stable" --build-arg=PYTHON_VER="3.11" --format docker ../ -f Dockerfile
echo "Run: ${engine} build ${opts[*]} ./ -f environments/Dockerfile"
${engine} build ${opts[*]} ./ -f environments/Dockerfile ${tagargs[*]}

# For each Image Tag
for imagetag in "${imagetags[@]}"
do
   # Tag & Upload to local Registry
   upload_to_local_registry "${imagetag}" "${engine}"
done
