while true
do
  eval engine create -c ~/snake-config-grenade.json \
  | jq --raw-output ".ID" \
  | xargs -I {} sh -c \
      "engine run -g {}"
  echo "eee"
  sleep 750
done
