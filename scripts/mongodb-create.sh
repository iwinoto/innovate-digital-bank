#!/bin/bash
if [[ -z $MONGO_SERVICE_NAME ]] then
    MONGO_SERVICE_NAME=compose-for-mongodb
fi
if [[ -z $MONGO_SERVICE_INSTANCE ]] then
    MONGO_SERVICE_INSTANCE=innovate-banking-mongo
fi
if [[ -z $MONGO_SERVICE_PLAN ]] then
    MONGO_SERVICE_PLAN=Standard
fi
if [[ -z $MONGO_KEY_NAME ]] then
    MONGO_KEY_NAME=mongodb-key-app01
fi
MICROSERVICES="accounts authentication bills portal support transactions userbase"

echo MONGO_SERVICE_NAME = $MONGO_SERVICE_NAME
echo MONGO_SERVICE_PLAN = $MONGO_SERVICE_PLAN
echo MONGO_SERVICE_INSTANCE = $MONGO_SERVICE_INSTANCE
echo MONGO_KEY_NAME = $MONGO_KEY_NAME

# Create Mongo DB service instance
ibmcloud cf cs $MONGO_SERVICE_NAME $MONGO_SERVICE_PLAN $MONGO_SERVICE_INSTANCE

# Create service instance key
ibmcloud cf create-service-key $MONGO_SERVICE_INSTANCE $MONGO_KEY_NAME

# Get key
ibmcloud cf service-key $MONGO_SERVICE_INSTANCE $MONGO_KEY_NAME | \
    awk '/^\{/{ JSONfound=1; JSONrow=NR} ; \
        (JSONfound && NR>=JSONrow) {print}' - \
    > innovate-banking-mongo-key.json

# Get instance URI
MONGO_URI=$(cat innovate-banking-mongo-key.json | jq -r .uri | sed 's/\//\\\//g' )

# Inject Mongo instance URI into microservice environments
for DIR in $(echo $MICROSERVICES)
do
    sed "s/<YOUR_MONGODB_CONNECTION_STRING>/$MONGO_URI/" ../$DIR/.env.example > ../$DIR/.env
done
