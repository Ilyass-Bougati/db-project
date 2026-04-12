# Dockerfile 
FROM gvenzl/oracle-xe:21-slim-faststart 
# Variables d'environnement 
ENV ORACLE_PASSWORD=admin 
ENV APP_USER=mon_user 
ENV APP_USER_PASSWORD=mon_mdp 
# Créer un répertoire pour les logs 
RUN mkdir -p /opt/oracle/logs 
# Copier les scripts SQL (ils seront exécutés automatiquement) 
ARG SCRIPTS="./scripts-rabat/*.sql"

COPY ${SCRIPTS} /container-entrypoint-initdb.d/ 
EXPOSE 1521 5500