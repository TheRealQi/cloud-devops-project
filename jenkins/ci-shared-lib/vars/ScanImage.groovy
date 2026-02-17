def call(String imageName, String imageTag) {
    sh "echo 'Scanning image ${imageName}:${imageTag} for vulnerabilities'"
    def status = sh(
            script: "trivy image --severity HIGH,CRITICAL --no-progress --format table ${imageName}:${imageTag}",
            returnStatus: true
    )
    if (status != 0) {
        echo "WARNING: High/Critical Vulnerabilities found."
    }
}