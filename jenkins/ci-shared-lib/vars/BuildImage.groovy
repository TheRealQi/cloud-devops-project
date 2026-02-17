def call(String workdir, String imageName, String imageTag) {
    dir(workdir) {
        sh """
            echo "Building Docker image ${imageName}:${imageTag} from directory ${workdir}"
            docker build -t ${imageName}:${imageTag} .
            echo "Successfully built Docker image ${imageName}:${imageTag}"
        """
    }
}
