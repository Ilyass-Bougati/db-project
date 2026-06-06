#!/usr/bin/bash

# warning the user
echo -e "\e[31mWARNING : \e[0m This script will delete all your containers, volumes and networks. You have 5s to stop before you do something that can't be undone"
sleep 5

# Stop all running containers
echo -e "\e[33mStopping all running docker containers\e[0m"
docker stop $(docker ps -a -q)

# delete all containers
echo -e "\e[33mDeleting all running docker containers\e[0m"
docker rm -fv $(docker ps -a -q)

# delete all volumes
echo -e "\e[33mDeleting all volumes\e[0m"
docker volume prune --all -f

# delete all networks
echo -e "\e[33mDeleting all networks\e[0m"
docker network prune -f

# delete all images
# echo -e "\e[33mDeleting all images\e[0m"
# docker rmi $(docker images -q)