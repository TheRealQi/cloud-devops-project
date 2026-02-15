def call(String imageRepo, String imageName, String imageTag) {
    sh """
        echo 'Pushing Docker image to Docker Hub'
        echo ${DOCKERHUB_PASS} | docker login -u ${DOCKERHUB_USER} --password-stdin
        docker push ${imageRepo}/${imageName}:${imageTag}
        echo 'Docker image pushed successfully'
    """
}
