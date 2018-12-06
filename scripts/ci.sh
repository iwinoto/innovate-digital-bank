#!/bin/bash

MICROSERVICES="accounts authentication bills portal support transactions userbase"

if [ "$REGISTRY_SERVICE" = "Docker" ]; then
# If using Docker hub as image registry
    if [[ -z $IMAGE_BUILDER ]]; then
        IMAGE_BUILDER="docker build"
    fi
    if [[ -z $REG_NAMESPACE ]]; then
        REG_NAMESPACE=iwinoto
    fi
    if [[ -z $REGISTRY ]]; then
        REGISTRY=$REG_NAMESPACE
    fi
else
# if Using IBM Container Registry service
    if [[ -z $IMAGE_BUILDER ]]; then
        IMAGE_BUILDER="ibmcloud cr build"
    fi
    if [[ -z $REG_REGION ]]; then
        REG_REGION=au-syd
    fi
    if [[ -z $REG_NAMESPACE ]]; then
        REG_NAMESPACE=iwinoto_ibm
    fi
    if [[ -z $REGISTRY ]]; then
        REGISTRY=registry.$REG_REGION.bluemix.net/$REG_NAMESPACE
    fi
fi

SERVICE_NAME_PREFIX="innovate"
if [[ -z $IMAGE_TAG ]]; then
    echo IMAGE_TAG is not set
    IMAGE_TAG=":v1.0.0"
else
    IMAGE_TAG=":$IMAGE_TAG"
fi

# Region for IBM Cloud api endpoint
if [[ -z $API_REGION ]]; then
    API_REGION=au-syd
fi

if [[ -z $MONGO_SERVICE_NAME ]]; then
    MONGO_SERVICE_NAME=compose-for-mongodb
fi
if [[ -z $MONGO_SERVICE_INSTANCE ]]; then
    MONGO_SERVICE_INSTANCE=innovate-banking-mongo
fi
if [[ -z $MONGO_SERVICE_PLAN ]]; then
    MONGO_SERVICE_PLAN=Standard
fi
if [[ -z $MONGO_KEY_NAME ]]; then
    MONGO_KEY_NAME=mongodb-key-app01
fi

echoVars() {
    echo MONGO_SERVICE_NAME [$MONGO_SERVICE_NAME]
    echo MONGO_SERVICE_PLAN [$MONGO_SERVICE_PLAN]
    echo MONGO_SERVICE_INSTANCE [$MONGO_SERVICE_INSTANCE]
    echo MONGO_KEY_NAME [$MONGO_KEY_NAME]
    echo REGISTRY_SERVICE [$REGISTRY_SERVICE]
    echo IMAGE_BUILDER [$IMAGE_BUILDER]
    echo REG_REGION [$REG_REGION]
    echo REG_NAMESPACE [$REG_NAMESPACE]
    echo REGISTRY [$REGISTRY]
    echo API_REGION [$API_REGION]
    echo SERVICE_NAME_PREFIX [$SERVICE_NAME_PREFIX]
    echo IMAGE_TAG [$IMAGE_TAG]
}

buildImages() {
    echoVars
    if [ "$REGISTRY_SERVICE" = "Docker" ]; then
        docker login -u $DOCKER_USER -p $DOCKER_PASSWD
    else
        echo Logging into Bluemix...
        ibmcloud api api.$API_REGION.bluemix.net
        ibmcloud login --apikey ${BLUEMIX_API_KEY}

        OUT=$(ibmcloud cr)
        if [ $? -ne 0 ]; then
            echo "We need the container registry plugin to do this stuff. Grabbing it..."
            ibmcloud plugin install -f container-registry
        else
            echo "Container registry plugin is installed."
        fi

        echo Configuring Docker for the IBM Container Registry...
        ibmcloud cr login
    fi

    for SERVICE in $(echo $MICROSERVICES); do
        IMAGE_NAME="$SERVICE_NAME_PREFIX-$SERVICE"
        echo "Building service $SERVICE to $REGISTRY/$IMAGE_NAME$IMAGE_TAG..."

        ${IMAGE_BUILDER} -t $REGISTRY/$IMAGE_NAME$IMAGE_TAG ../$SERVICE
        docker push $REGISTRY/$IMAGE_NAME$IMAGE_TAG
    done
}

deployLatest() {
    for SERVICE in $(echo $MICROSERVICES); do
        helm install ../$SERVICE/chart/$SERVICE_NAME_PREFIX-$SERVICE --name $SERVICE_NAME_PREFIX-$SERVICE
    done
}

deployIstioConfig() {
    # If Istio is deployed in the cluster and the services are calling
    # services external to the mesh, a ServiceEntry and corresponding
    # VirtualService rule needs to be applied.
    # Otherwise Istio proxies will not route traffic to external services.
    kubectl apply -f istio-ServiceEntry-MongoDB.yaml
    kubectl apply -f istio-VirtualService-MongoDB.yaml
}

dbCreate(){
    echoVars
     # Create Mongo DB service instance
    ibmcloud cf cs $MONGO_SERVICE_NAME $MONGO_SERVICE_PLAN $MONGO_SERVICE_INSTANCE

    # Create service instance key
    ibmcloud cf create-service-key $MONGO_SERVICE_INSTANCE $MONGO_KEY_NAME

    # Get key
    ibmcloud cf service-key $MONGO_SERVICE_INSTANCE $MONGO_KEY_NAME | \
        awk '/^\{/{ JSONfound=1; JSONrow=NR} ; \
            (JSONfound && NR>=JSONrow) {print}' - \
        > innovate-banking-mongo-key.json

    # Get instance URI and escape the special characters for sed regex
    MONGO_URI=$(cat innovate-banking-mongo-key.json | jq -r .uri | sed 's/\([/&]\)/\\\1/g')
    echo Escaped MONGO_URI = $MONGO_URI

    # Inject Mongo instance URI into microservice environments
    for DIR in $(echo $MICROSERVICES)
    do
        sed "s/<YOUR_MONGODB_CONNECTION_STRING>/$MONGO_URI/g" ../$DIR/.env.example > ../$DIR/.env
    done
}

usage() {
    cat <<-EOF

Usage: $0 {dbCreate|build|deploy|istio}

dbCreate    Creates a DB service (currently only Compose for Mongo) instance,
        creates a service API key and set the credentials in the µservice
        .env file.

build   Logs into Bluemix using BLUEMIX_API_KEY environment variable
        and builds all the images in this project. Where possible, it
        uses the ibmcloud cr command instead of docker build, so as to
        limit the amount of disk space used (ibmcloud cr images get built
        on IKS servers)

        When finished, everything in the namespace for this project should
        be the latest images built based on master.

deploy  Connects to the k8s cluster in IBM Container Service as per the
        current context (kubectl config current-context), including namepsace
        and deploys each µservice helm chart

istio   Deploys istio rules to allow in mesh µservices to send requests to
        services external to the mesh. In this case, the service is the
        Compose for Mongo service on IBM Cloud.

The Following environment variables can be set:
DOCKER_USER
DOCKER_PASSWD
EOF

    echoVars
    exit 1
}

case "$1" in
  dbCreate)
    dbCreate
    ;;
  build)
    buildImages
    ;;
  deploy)
    deployLatest
    ;;
  istio)
    deployIstioConfig
    ;;
  *)
    usage
esac
