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

echo REGISTRY_SERVICE = $REGISTRY_SERVICE
echo IMAGE_BUILDER = $IMAGE_BUILDER
echo REG_REGION = $REG_REGION
echo REG_NAMESPACE $REG_NAMESPACE
echo REGISTRY = $REGISTRY
echo API_REGION = $API_REGION
echo SERVICE_NAME_PREFIX = $SERVICE_NAME_PREFIX
echo IMAGE_TAG = $IMAGE_TAG

buildImages() {

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

case "$1" in
  build)
    buildImages
    ;;
  deploy)
    deployLatest
    ;;
  ingress)
    deployIngress
    ;;
  certs)
    certs
    ;;
  *)
    usage
esac
