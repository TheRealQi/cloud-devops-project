def call(String imageRepo, String imageName, String imageTag) {
    sh """
        echo "Removing Docker image ${IMAGE_REPO}/${IMAGE_NAME}:${IMAGE_TAG} locally"
        docker rmi ${IMAGE_REPO}/${IMAGE_NAME}:${IMAGE_TAG} || true"
        echo "Docker image ${IMAGE_REPO}/${IMAGE_NAME}:${IMAGE_TAG} removed locally"
    """
}

