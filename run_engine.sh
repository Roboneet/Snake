#!/bin/bash
# after starting server and board

ENGINE_URL=http://localhost:3005

eval engine create -c ${1:-~/snake-config.json} \
  | jq --raw-output ".ID" \
  | xargs -I {} sh -c \
      "open -a \"Google Chrome\" \
          \"http://localhost:3000/?engine=${ENGINE_URL}&game={}\" \
        && engine run -g {}"
