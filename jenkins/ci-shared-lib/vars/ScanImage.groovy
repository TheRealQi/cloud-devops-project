def call(String imageRepo, String imageName, String imageTag) {
    sh "echo 'Scanning image ${imageRepo}/${imageName}:${imageTag} for vulnerabilities'"
    def status = sh(
            script: "trivy image --severity HIGH,CRITICAL --no-progress --format table ${imageRepo}/${imageName}:${imageTag}",
            returnStatus: true
    )
    if (status != 0) {
        echo "WARNING: High/Critical Vulnerabilities found."
    }
}