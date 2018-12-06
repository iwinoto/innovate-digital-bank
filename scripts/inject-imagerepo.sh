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
    sed -e "s/  repository: .*/  repository: $REPO/" -i "" ../$DIR/chart/innovate-$DIR/values.yaml
    sed -e "s/deploy-image-target: .*/deploy-image-target: \"$REPO\"/" -i "" ../$DIR/cli-config.yml
done

# test in regex tester
# Hint at regex of image repo is found here: https://github.com/docker/distribution/blob/master/docs/spec/api.md#overview
# 01
# sed "s/\([ \t]repository:\)\s\([a-z0-9]+\(?:[._-][a-z0-9]+\)*.\)\([a-z0-9]+\(?:[._-][a-z0-9]+\)*.\)/\1 $REG_NAMESPACE\//"
# 02
# sed "s/\([ \t]repository:\)[ \t]\([a-z0-9]+\(?:[._-][a-z0-9]+\)*.\)\([a-z0-9]+\(?:[._-][a-z0-9]+\)*.\)/\1 iwinoto\//g"
