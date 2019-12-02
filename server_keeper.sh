while true
do
  eval engine create -c ~/snake-config.json \
  | jq --raw-output ".ID" \
  | xargs -I {} sh -c \
      "engine run -g {}"

  sleep 750
done
