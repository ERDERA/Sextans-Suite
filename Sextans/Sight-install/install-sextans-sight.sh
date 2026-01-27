#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
CWD=$PWD
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0


function ctrl_c() {
        docker compose -f "$CWD/config/docker-compose-${P}.yml" down
        docker compose -f "$CWD/bootstrap/docker-compose-${P}.yml" down
        docker compose rm -f "$CWD/config/docker-compose-${P}.yml" -s
        docker compose rm -f "$CWD/bootstrap/docker-compose-${P}.yml" -s
        docker network rm bootstrap_default bootstrap_graphdb_net
        docker rmi -f bootstrap_graph_db_repo_manager:latest

        rm "${CWD}/config/docker-compose-${P}.yml"
        rm "${CWD}/bootstrap/docker-compose-${P}.yml"
        rm "${CWD}/config/fdp/application-${P}.yml"

        exit 2
}

trap ctrl_c 2

production="true"


if [ $production = "true" ]; then
  echo "Sextans Sight Installation in Demilitarized Zone"
  read -p "Your permanent GUID (e.g. https://w3id.org/my-organization): " uri
fi

if [ -z $P ]; then
  read -p "enter a prefix for your components (e.g. euronmd) NOTE: All existing installations with the same prefix will be obliterated!!!!: " P
  if [ -z $P ]; then
    echo "invalid..."
    exit 1
  fi
fi

if [ -z $FDP_PORT ]; then
  read -p "Enter the port for your your Sight Server (e.g. 7070): " FDP_PORT
  if [ -z $FDP_PORT ]; then
    echo "invalid..."
    exit 1
  fi
fi

if [ -z $GDB_PORT ]; then
  read -p "Enter the port where your GraphDB will serve (e.g. 7200): " GDB_PORT
  if [ -z $GDB_PORT ]; then
    echo "invalid..."
    exit 1
  fi
fi


mkdir $HOME/tmp
export TMPDIR=$HOME/tmp
# PREFIX needed by the main.py script and docker composes
export FDP_PREFIX=$P

docker network rm bootstrap_sight__default
docker ps -a | egrep -oh "${P}-Sextans.*" | xargs docker rm
docker rm -f  bootstrap_sight_graphdb_1 config_fdp_1 config_fdp_client_1
docker volume remove -f "${P}-graphdb ${P}-fdp-client-assets ${P}-fdp-client-css ${P}-fdp-client-scss ${P}-fdp-server ${P}-mongo-data ${P}-mongo-init"

docker volume create "${P}-graphdb"
docker volume create "${P}-sight-server"
docker volume create "${P}-sight-client-assets"
docker volume create "${P}-sight-client-scss"
docker volume create "${P}-mongo-data"
docker volume create "${P}-mongo-init"


echo ""
echo ""
echo -e "${GREEN}Creating GraphDB and bootstrapping it - this will take about a minute"
echo -e "Go make a nice cup of tea and then come back to check on progress"
echo -e "${NC}"
echo ""

cd bootstrap_sight
cp docker-compose-template.yml "docker-compose-${P}.yml"
sed -i'' -e "s/{PREFIX}/${P}/" "docker-compose-${P}.yml"
docker compose -f "docker-compose-${P}.yml" down
sleep 5

docker compose -f "docker-compose-${P}.yml" up --build -d
sleep 180

echo ""
echo -e "${GREEN}Setting up Sextans Sight client and server${NC}"
echo ""




cd ../config

cp docker-compose-template.yml "docker-compose-${P}.yml"
cp ./fdp/application-template.yml "./fdp/application-${P}.yml"
sed -i'' -e "s/{PREFIX}/$P/" "docker-compose-${P}.yml"
sed -i'' -e "s/{FDP_PORT}/$FDP_PORT/" "docker-compose-${P}.yml"
sed -i'' -e "s/{PREFIX}/$P/" "./fdp/application-${P}.yml"
sed -i'' -e "s/{FDP_PORT}/$FDP_PORT/" "./fdp/application-${P}.yml"
sed -i'' -e "s%{GUID}%$uri%" "./fdp/application-${P}.yml"

#docker compose -f "docker-compose-${P}.yml" down
#sleep 5

#docker compose -f "docker-compose-${P}.yml" up --build -d
docker compose -f "docker-compose-${P}.yml" up --build 


sleep 180

echo ""
echo -e "${GREEN}Creating a production server folder in ${NC} ./${P}-Sextans-Sight/"
echo ""

cd ..
cp -r ./Sextans-Sight ./${P}-Sextans-Sight
cp ./docker-compose-template.yml "./${P}-Sextans-Sight/docker-compose-${P}.yml"
cp ./${P}-Sextans-Sight/fdp/application-template.yml "./${P}-Sextans-Sight/fdp/application-${P}.yml"
rm ./${P}-Sextans-Sight/fdp/application-template.yml
cp ./${P}-Sextans-Sight/.env_template "./${P}-Sextans-Sight/.env"
sed -i'' -e "s/{PREFIX}/${P}/" "./${P}-Sextans-Sight/docker-compose-${P}.yml"
sed -i'' -e "s/{FDP_PORT}/${FDP_PORT}/" "./${P}-Sextans-Sight/docker-compose-${P}.yml"
sed -i'' -e "s/{GDB_PORT}/${GDB_PORT}/" "./${P}-Sextans-Sight/docker-compose-${P}.yml"
sed -i'' -e "s/{PREFIX}/${P}/" "./${P}-Sextans-Sight/fdp/application-${P}.yml"
sed -i'' -e "s/{FDP_PORT}/${FDP_PORT}/" "./${P}-Sextans-Sight/fdp/application-${P}.yml"
sed -i'' -e "s%{GUID}%${uri}%" "./${P}-Sextans-Sight/fdp/application-${P}.yml"
sed -i'' -e "s%{GUID}%$uri%" "./${P}-Sextans-Sight/.env"



echo -e "${GREEN}Installation Complete!"
echo -e "${GREEN}Now doing post-install clean-up..."

docker compose -f "${CWD}/config/docker-compose-${P}.yml" down
docker compose -f "${CWD}/bootstrap_sight/docker-compose-${P}.yml" down
docker compose -f "${CWD}/config/docker-compose-${P}.yml" rm -s -f
docker compose -f "${CWD}/bootstrap_sight/docker-compose-${P}.yml" rm -s -f
docker network rm bootstrap_sight_default bootstrap_sight_graphdb_net
docker rmi -f bootstrap_sight_graph_db_repo_manager:latest

rm "${CWD}/config/docker-compose-${P}.yml"
rm "${CWD}/bootstrap_sight/docker-compose-${P}.yml"
rm "${CWD}/config/fdp/application-${P}.yml"

echo ""
echo -e "${GREEN}DONE!"
echo ""
echo -e "${GREEN}Please now move into the ${NC} ./${P}-Sextans-Sight/ ${GREEN} folder where the full version of the docker-compose-{P}.yml file lives."
echo ""
echo -e "${GREEN}To start your full Sextans Sight server, cd to that folder (or move it elsewhere) and and type:  "
echo -e "docker-compose -f docker-compose-${P}.yml up -d ${NC}"
echo ""

