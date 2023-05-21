IMAGE_NAME="hotpotato"
TAG="10m"
REPO="ttl.sh"

build: 	## Build docker image
	docker build -t ${REPO}/${IMAGE_NAME}:${TAG} .

push:	## Push docker image to repo
	docker push ${REPO}/${IMAGE_NAME}:${TAG}

compose:	## Run locally using docker compose
	docker-compose up

run:	## Run the image locally
	docker run \
		-p 4567:4567 \
		-d \
		--rm \
		--name ${IMAGE_NAME} \
		${REPO}/${IMAGE_NAME}:${TAG}

helm:	## helm upgrade --install
	helm upgrade ${IMAGE_NAME} --install -f helm-chart/values.yaml helm-chart -n ${IMAGE_NAME} --create-namespace

delete: ## helm delete release
	helm delete ${IMAGE_NAME}

release:	## make build && make push && helm delete boromore && make helm
	make build && make push && make helm

help: ## Display this output.
	@egrep '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: clean help erd build push run helm release pghelm cluster remove
.DEFAULT_GOAL := help
