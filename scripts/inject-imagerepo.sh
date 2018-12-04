#!/bin/bash

if [[ -z $REG_NAMESPACE ]] then
    REG_NAMESPACE="iwinoto"
fi

MICROSERVICES="accounts authentication bills portal support transactions userbase"

# Inject image registry namespace into microservice chart values.yaml
for DIR in $(echo $MICROSERVICES)
do
    REPO=$(echo $REG_NAMESPACE/innovate-$DIR | sed 's/\//\\\//g' )
    echo $REPO
    sed "s/  repository: .*/  repository: $REPO/" ../$DIR/chart/innovate-$DIR/values.yaml > ../$DIR/chart/innovate-$DIR/values.yaml
    sed "s/deploy-image-target: .*/deploy-image-target: \"$REPO\"/" ../$DIR/cli-config.yml > ../$DIR/cli-config.yml
done

# test in regex tester
# Hint at regex of image repo is found here: https://github.com/docker/distribution/blob/master/docs/spec/api.md#overview
# 01
# sed "s/([ \t]repository:)\s([a-z0-9]+(?:[._-][a-z0-9]+)*.)([a-z0-9]+(?:[._-][a-z0-9]+)*.)/\$1 $REG_NAMESPACE\//"
# 02
# sed "s/([ \t]repository:)[ \t]([a-z0-9]+(?:[._-][a-z0-9]+)*.)([a-z0-9]+(?:[._-][a-z0-9]+)*.)/$1 iwinoto\//g"
