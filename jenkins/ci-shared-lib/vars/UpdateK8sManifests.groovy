def call(String workdir,String imageName, String imageTag) {
    dir(workdir) {
        sh """
        echo 'Editing App. Deployment Manifest'
        sed -i 's|image:.*|image: ${imageName}:${imageTag}|g' deployment.yaml
        echo 'App. Deployment Manifest edited successfully'
        """
    }
}