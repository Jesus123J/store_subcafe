#!/usr/bin/env bash
# Arranca el backend en local (macOS / Linux).
#   ./run.sh              -> perfil por defecto (MySQL local root/123456, BD financialtracker1)
#   ./run.sh local        -> usa application-local.yml
# Requiere: JDK 17+ y el contenedor MySQL "mysql-proyectos" encendido
#   (cd ~/Desktop/me/mysql-db && docker compose up -d)
set -e
cd "$(dirname "$0")"

# Elegir un JDK 17+ si el de por defecto es mas viejo (en Mac: /usr/libexec/java_home)
if command -v /usr/libexec/java_home >/dev/null 2>&1; then
  for v in 21 17; do
    if JH=$(/usr/libexec/java_home -v "$v" 2>/dev/null); then export JAVA_HOME="$JH"; break; fi
  done
fi

PROFILE_ARG=""
if [ -n "$1" ]; then PROFILE_ARG="-Dspring-boot.run.profiles=$1"; fi

echo "JAVA_HOME=${JAVA_HOME:-<por defecto>}"
exec ./mvnw -q spring-boot:run $PROFILE_ARG
