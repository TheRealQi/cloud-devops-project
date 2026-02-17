def call(String imageRepo, String imageName, String imageTag, String awsAccountID, String awsRegion) {
    sh """
        echo 'Pushing Docker image to Docker Hub'
        aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${awsAccountID}.dkr.ecr.${awsRegion}.amazonaws.com
        docker push ${imageRepo}/${imageName}:${imageTag}
        echo 'Docker image pushed successfully'
    """
}
