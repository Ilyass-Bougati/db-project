#!/usr/bin/bash

docker stop oracle-site-1
docker rm oracle-site-1
docker volume rm ilyass_site-1-data
docker compose up -d