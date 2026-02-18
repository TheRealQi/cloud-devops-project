def call(String workdir,String ecrURI, String imageTag) {
    dir(workdir) {
        sh """
        echo 'Editing App. Deployment Manifest'
        sed -i 's|image:.*|image: ${ecrURI}:${imageTag}|g' deployment.yaml
        echo 'App. Deployment Manifest edited successfully'
        """
    }
}