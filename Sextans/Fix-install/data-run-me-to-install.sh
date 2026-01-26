#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
CWD=$PWD
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0


function ctrl_c() {
        docker-compose -f "$CWD/metadata/docker-compose-${P}.yml" down
        docker-compose -f "$CWD/bootstrap/docker-compose-${P}.yml" down
        docker-compose rm -f "$CWD/metadata/docker-compose-${P}.yml" -s
        docker-compose rm -f "$CWD/bootstrap/docker-compose-${P}.yml" -s
        docker network rm bootstrap_default bootstrap_graphdb_net
        docker rmi -f bootstrap_graph_db_repo_manager:latest

        if [ $production = "false" ]; then
          echo ""
          echo -e "${GREEN}because this is NOT a production server, I will now delete all assets and volumes.  You must re-run this installation script as a production server to recover.$NC"
          echo ""
          rm -rf "$CWD/test-ready-to-go"
          docker volume remove -f $P-graphdb $P-fdp-client-assets $P-fdp-client-css $P-fdp-client-scss $P-fdp-server $P-mongo-data $P-mongo-init
        fi
        rm "${CWD}/metadata/docker-compose-${P}.yml"
        rm "${CWD}/bootstrap/docker-compose-${P}.yml"
        rm "${CWD}/metadata/fdp/application-${P}.yml"

        exit 2
}

trap ctrl_c 2

production="true"


if [ $production = "true" ]; then
  echo "Data Server Secure Environment Installation"
fi

if [ -z $P ]; then
  read -p "enter a prefix for your components (e.g. euronmd) NOTE: All existing installations with the same prefix will be obliterated!!!!: " P
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
  read -p "Enter the port where your GraphDB will CARE-SM Data (e.g. 7200) (set it, but IT WILL NOT BE EXPOSED BY DEFAULT): " GDB_PORT
  if [ -z $GDB_PORT ]; then
    echo "invalid..."
    exit 1
  fi
fi


if [ -z $BEACON_PORT ]; then
  read -p  "Enter the port where your Beacon2 will serve (e.g. 8000) (set this, even if not used): " BEACON_PORT
  if [ -z $BEACON_PORT ]; then
    echo "invalid..."
    exit 1
  fi
fi


mkdir $HOME/tmp
export TMPDIR=$HOME/tmp
# needed by the main.py script
export FDP_PREFIX=$P

docker network rm bootstrap_default
docker ps -a | egrep -oh "${P}-ready-to-go.*" | xargs docker rm
docker rm -f  bootstrap_graphdb_1 metadata_fdp_1 metadata_fdp_client_1
docker volume remove -f "${P}-graphdb ${P}-fdp-client-assets ${P}-fdp-client-css ${P}-fdp-client-scss ${P}-fdp-server ${P}-mongo-data ${P}-mongo-init"

docker volume create "${P}-graphdb"

echo ""
echo ""
echo -e "${GREEN}Creating GraphDB and bootstrapping it - this will take about a minute"
echo -e "Go make a nice cup of tea and then come back to check on progress"
echo -e "${NC}"
echo ""

cd bootstrap
cp docker-compose-template.yml "docker-compose-${P}.yml"
sed -i'' -e "s/{PREFIX}/${P}/" "docker-compose-${P}.yml"

docker-compose -f "docker-compose-${P}.yml" up --build -d
sleep 120

echo ""
echo -e "${GREEN}Creating a CARE-SM production server folder in ${NC} ./${P}-caresm-ready-to-go/"
echo ""

cd ..
cp -r ./FAIR-ready-to-go ./${P}-caresm-ready-to-go
cp ./${P}-ready-to-go/docker-compose-template.yml "./${P}-caresm-ready-to-go/docker-compose-${P}.yml"
rm ./${P}-ready-to-go/docker-compose-template.yml
cp ./${P}-ready-to-go/fdp/application-template.yml "./${P}-caresm-ready-to-go/fdp/application-${P}.yml"
rm ./${P}-ready-to-go/fdp/application-template.yml
cp ./${P}-ready-to-go/.env_template "./${P}-caresm-ready-to-go/.env"
sed -i'' -e "s/{PREFIX}/${P}/" "./${P}-caresm-ready-to-go/docker-compose-${P}.yml"
sed -i'' -e "s/{GDB_PORT}/${GDB_PORT}/" "./${P}-caresm-ready-to-go/docker-compose-${P}.yml"
sed -i'' -e "s/{BEACON_PORT}/${BEACON_PORT}/" "./${P}-caresm-ready-to-go/docker-compose-${P}.yml"
sed -i'' -e "s/{RDF_TRIGGER}/${RDF_TRIGGER}/" "./${P}-caresm-ready-to-go/docker-compose-${P}.yml"
sed -i'' -e "s/{PREFIX}/${P}/" "./${P}-caresm-ready-to-go/fdp/application-${P}.yml"
sed -i'' -e "s%{GUID}%${uri}%" "./${P}-caresm-ready-to-go/fdp/application-${P}.yml"
sed -i'' -e "s/{CDE_DB_NAME}/${P}-cde/" "./${P}-caresm-ready-to-go/.env"
sed -i'' -e "s%{GUID}%$uri%" "./${P}-caresm-ready-to-go/.env"

echo ""
echo ""
echo -e "${GREEN}Installation Complete!"
echo -e  "${GREEN}you now have 10 minutes to test things."  
echo -e  "${GREEN}If GraphDB is working, you should be able to access it at: http://localhost:7200  (NOTE: this is NOT the port that will serve GraphDB in your production service!  This is only used for the test phase you are currently doing..."
echo -e  "${GREEN}You can stop this test phase at any time with CTRL-C (ONLY ONCE!!!!!  Let the cleanup routine run, or you will be unhappy!), then wait for the docker images to shut down cleanly before continuing${NC}"
if [ $production = "true" ]; then
  echo -e  "${GREEN}If you stop this test phase because it was successful, please note that you must cd into the ${NC}'${P}-ready-to-go'${GREEN} folder to start the production server ${NC}"
fi

sleep 600
docker-compose -f "${CWD}/metadata/docker-compose-${P}.yml" down
docker-compose -f "${CWD}/bootstrap/docker-compose-${P}.yml" down
docker-compose -f "${CWD}/metadata/docker-compose-${P}.yml" rm -s -f
docker-compose -f "${CWD}/bootstrap/docker-compose-${P}.yml" rm -s -f
docker network rm bootstrap_default bootstrap_graphdb_net
docker rmi -f bootstrap_graph_db_repo_manager:latest

if [ $production = "false" ]; then
  echo ""
  echo -e "${GREEN}because this is NOT a production server, I will now delete all assets and volumes.  You must re-run this installation script as a production server to recover.$NC"
  echo ""
  docker volume remove -f $P-graphdb $P-fdp-client-assets $P-fdp-client-css $P-fdp-client-scss $P-fdp-server $P-mongo-data $P-mongo-init
fi

rm "${CWD}/metadata/docker-compose-${P}.yml"
rm "${CWD}/bootstrap/docker-compose-${P}.yml"
rm "${CWD}/metadata/fdp/application-${P}.yml"

echo ""
echo -e "${GREEN}Shutdown Complete.  Please now move into the ${NC} ./${P}-ready-to-go/ ${GREEN} folder where the full version of the docker-compose-{P}.yml file lives."
echo ""
echo -e "${GREEN}To start your full FAIR-in-a-box server, cd to that folder (or move it elsewhere) and and type:  "
echo -e "docker-compose -f docker-compose-${P}.yml up -d ${NC}"
echo ""

