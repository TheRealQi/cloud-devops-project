def call(String imageName, String imageTag, String awsAccountID, String awsRegion) {
    sh """
        echo 'Pushing Docker image to ECR'
        aws ecr get-login-password --region ${awsRegion} | \
        docker login --username AWS --password-stdin ${awsAccountID}.dkr.ecr.${awsRegion}.amazonaws.com
        docker tag ${imageName}:${imageTag} ${awsAccountID}.dkr.ecr.${awsRegion}.amazonaws.com/${imageName}:${imageTag}
        docker push ${awsAccountID}.dkr.ecr.${awsRegion}.amazonaws.com/${imageName}:${imageTag}
        echo 'Docker image pushed successfully'
    """
}
