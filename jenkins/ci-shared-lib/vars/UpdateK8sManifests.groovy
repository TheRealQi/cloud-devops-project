def call(String workdir, String imageRepo, String imageName, String imageTag) {
    dir(workdir) {
        sh """
        echo 'Editing App. Deployment Manifest'
        sed -i 's|image:.*|image: ${imageRepo}/${imageName}:${imageTag}|g' deployment.yaml
        echo 'App. Deployment Manifest edited successfully'
        """
    }
}