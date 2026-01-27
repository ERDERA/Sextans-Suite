#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
CWD=$PWD
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0


function ctrl_c() {
        docker-compose -f "$CWD/bootstrap_fix/docker-compose-${P}.yml" down
        docker-compose rm -f "$CWD/bootstrap_fix/docker-compose-${P}.yml" -s
        docker network rm bootstrap_default bootstrap_graphdb_net
        docker rmi -f bootstrap_graph_db_repo_manager:latest

        rm "${CWD}/bootstrap/docker-compose-${P}.yml"

        exit 2
}

trap ctrl_c 2

production="true"


if [ $production = "true" ]; then
  echo "Sextans Fix Server Secure Environment Installation"
fi

if [ -z $P ]; then
  read -p "enter a prefix for your components (e.g. euronmd) NOTE: All existing installations IN THE SECURE SPACE with the same prefix will be obliterated!!!!: " P
  if [ -z $P ]; then
    echo "invalid..."
    exit 1
  fi
fi

if [ -z $RDF_TRIGGER ]; then
  read -p "Enter the port that will trigger your CSV to CARE-SM Data transformation (e.g. 4567): " RDF_TRIGGER
  if [ -z $RDF_TRIGGER ]; then
    echo "invalid..."
    exit 1
  fi
fi


if [ -z $GDB_PORT ]; then
  read -p "Enter the port where your GraphDB will serve CARE-SM Data (e.g. 7200) (please set it, but IT WILL NOT BE EXPOSED BY DEFAULT): " GDB_PORT
  if [ -z $GDB_PORT ]; then
    echo "invalid..."
    exit 1
  fi
fi


# if [ -z $BEACON_PORT ]; then
#   read -p  "Enter the port where your Beacon2 will serve (e.g. 8000) (set this, even if not used): " BEACON_PORT
#   if [ -z $BEACON_PORT ]; then
#     echo "invalid..."
#     exit 1
#   fi
# fi


mkdir $HOME/tmp
export TMPDIR=$HOME/tmp
# needed by the main.py script
export FDP_PREFIX=$P

docker network rm bootstrap_fix_default
docker ps -a | egrep -oh "${P}-Sextans.*" | xargs docker rm
docker rm -f  bootstrap_fix_graphdb_1 
docker volume remove -f "${P}-graphdb"

docker volume create "${P}-graphdb"

echo ""
echo ""
echo -e "${GREEN}Creating GraphDB and bootstrapping it - this will take about a minute"
echo -e "Go make a nice cup of tea and then come back to check on progress"
echo -e "${NC}"
echo ""

cd bootstrap_fix
cp docker-compose-template.yml "docker-compose-${P}.yml"
sed -i'' -e "s/{PREFIX}/${P}/" "docker-compose-${P}.yml"

docker-compose -f "docker-compose-${P}.yml" up --build -d
sleep 120

echo ""
echo -e "${GREEN}Creating a Sextans Fix Production Server folder in ${NC} ./${P}-Sextans-Fix/"
echo ""

cd ../Sextans-Fix
mkdir ./${P}-Sextans-Fix
cp -r ./data ./${P}-Sextans-Fix/

cp ./docker-compose-template.yml "./${P}-Sextans-Fix/docker-compose-${P}.yml"
cp ./.env_template "./${P}-Sextans-Fix/.env"
sed -i'' -e "s/{PREFIX}/${P}/" "./${P}-Sextans-Fix/docker-compose-${P}.yml"
sed -i'' -e "s/{GDB_PORT}/${GDB_PORT}/" "./${P}-Sextans-Fix/docker-compose-${P}.yml"
# sed -i'' -e "s/{BEACON_PORT}/${BEACON_PORT}/" "./${P}-Sextans-Fix/docker-compose-${P}.yml"
sed -i'' -e "s/{RDF_TRIGGER}/${RDF_TRIGGER}/" "./${P}-Sextans-Fix/docker-compose-${P}.yml"
sed -i'' -e "s/{SEXTANS_DB_NAME}/${P}-cde/" "./${P}-Sextans-Fix/.env"
sed -i'' -e "s%{GUID}%$uri%" "./${P}-Sextans-Fix/.env"

echo ""
echo ""
echo -e "${GREEN}Installation Complete!"

echo -e "${GREEN}Now doing post-install clean-up..."

docker compose -f "${CWD}/bootstrap_fix/docker-compose-${P}.yml" down
docker compose -f "${CWD}/bootstrap_fix/docker-compose-${P}.yml" rm -s -f
docker network rm bootstrap_sight_default bootstrap_sight_graphdb_net
docker rmi -f bootstrap_sight_graph_db_repo_manager:latest

rm "${CWD}/bootstrap_sight/docker-compose-${P}.yml"

echo ""
echo -e "${GREEN}DONE!"
echo ""


docker-compose -f "${CWD}/bootstrap_fix/docker-compose-${P}.yml" down
docker-compose -f "${CWD}/bootstrap_fix/docker-compose-${P}.yml" rm -s -f
docker network rm bootstrap_fix_default bootstrap_fix_graphdb_net
docker rmi -f bootstrap_fix_graph_db_repo_manager:latest

rm "${CWD}/bootstrap_fix/docker-compose-${P}.yml"

echo ""
echo -e "${GREEN}Shutdown Complete.  Please now move into the ${NC} ./${P}-Sextans-Fix/ ${GREEN} folder where the full version of the docker-compose-{P}.yml file lives."
echo ""
echo -e "${GREEN}To start the SECURE ENVIRONMENT SEXTANS FIX DATA SERVER, cd to that folder (or move it elsewhere) and and type:  "
echo -e "docker-compose -f docker-compose-${P}.yml up -d ${NC}"
echo ""

