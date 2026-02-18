# Phase 1 & 2: App. Cloning and Dockerization
## 1. App. Repository Cloning
Cloned the Flask application source code to my local development environment.
```bash
git clone  https://github.com/Ibrahim/Adel15/FinalProject.git app
cd app
```

## 2. App. Dockerfile Definition & Explanation

### 2.1 Dockerfile Definition

```dockerfile
FROM python:3.14-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

### 2.2 Dockerfile Explanation

- `FROM python:3.14-slim`:
  - This line specifies the base image for the Docker container. It pulls the Python 3.14 slim version, which is a lightweight version of the Python image, ideal for reducing image size.

- `WORKDIR /app`
  - Sets the working directory to /app. Any subsequent commands like COPY or RUN will be executed relative to this directory.

- `COPY requirements.txt .`
  - Copies the requirements.txt file from the local directory to the /app directory in the container.

- `RUN pip install --no-cache-dir -r requirements.txt`
  - Installs the dependencies listed in requirements.txt using pip. The --no-cache-dir flag prevents caching, helping to keep the image size smaller.

- `COPY . .`
  - Copies the entire app source code from the local directory to the working directory /app in the container.

- `EXPOSE 5000`
  - Exposes port 5000 on the container.

- `CMD ["python", "app.py"]`
    - Specifies the default command to run when the container starts. It tells the container to run the app.py Python script, which is the main entry point for the Flask app.
