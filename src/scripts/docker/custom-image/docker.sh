#!/bin/bash

name=marklogiv

run () {
  docker-compose -f docker-compose.dev.yml up --build
}

build() {
  docker build -t ${mame}-app .
}

# loop over all arguments and execute them.
# If --run is passed, run the run function
# If --build is passed, run the build function
if [ $# -eq 0 ]; then
  echo "No arguments provided"
  exit 1
fi
while [ "$#" -gt 0 ]; do
  case "$1" in
    --run)
      run
      ;;
    --build)
      build
      ;;
    --stop)
      docker stop ${mame}-instance
      ;;
    --rm)
      docker rm ${mame}-instance
      ;;
    --login)
      docker exec -it ${mame}-instance /bin/bash
      ;;
    *)
      echo "Invalid argument: $1"
      ;;
  esac
  shift
done

