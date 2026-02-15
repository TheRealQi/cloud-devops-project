def call(String workdir, String imageRepo, String imageName, String imageTag) {
    dir(workdir) {
        sh """
            echo "Building Docker image ${imageRepo}/${imageName}:${imageTag} from directory ${workdir}"
            docker build -t ${imageRepo}/${imageName}:${imageTag} ."
            echo "Successfully built Docker image ${imageRepo}/${imageName}:${imageTag}"
        """
    }
}
