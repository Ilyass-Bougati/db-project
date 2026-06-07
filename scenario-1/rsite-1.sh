#!/usr/bin/bash

docker compose stop db-site-1
docker compose rm -f db-site-1
docker volume rm scenario-1_site-1-data
docker compose up -d db-site-1