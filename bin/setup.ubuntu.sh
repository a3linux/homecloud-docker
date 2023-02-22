#!/usr/bin/env bash
# Setup Ubuntu
# Verified on Ubuntu Server LTS 22.04
#

mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")
REPO_PATH=${MYSELF_PATH%%\/bin}
echo "Installing Ubuntu packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y $(cat "${REPO_PATH}"/etc/pkg.list.ubuntu)

# Install or upgrade Docker-ce
# From Docker official document https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo "Setup Docker official APT repository ..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
echo "Installing Docker Community Engine from Docker official repository ..."
sudo apt update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo gpasswd -a "${LOGNAME}" docker
echo "Run docker hello-world ..."
docker run --rm hello-world
echo "Create docker network homecloud"
docker network create homecloud

echo "Download standalone docker-compose ..."
mkdir -p "${HOME}"/bin
DOCKER_COMPOSE_VERSION=$(docker compose version | cut -d' ' -f4)
/usr/bin/curl -SL https://github.com/docker/compose/releases/download/"${DOCKER_COMPOSE_VERSION}"/docker-compose-linux-x86_64 -o "${HOME}"/bin/docker-compose
chmod +x "${HOME}"/bin/docker-compose

cp -v "${MYSELF_PATH}"/gen_passwd.sh "${HOME}"/bin/
cp -v "${MYSELF_PATH}"/passwd_util.py "${HOME}"/bin/
