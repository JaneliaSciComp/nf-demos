# Staged build using builder container
FROM janeliascicomp/builder:1.2.1 as builder
ARG GIT_TAG=master

# Checkout and build the code
WORKDIR /tmp/app
RUN git clone --branch $GIT_TAG --depth 1 https://github.com/saalfeldlab/n5-spark . \
    && /usr/local/bin/buildinfo.sh \
    && mvn package -P fatjar,spark-local

# Find the built jar, based on the version in the pom file
RUN xq -r '.project.artifactId+"-"+.project.version+".jar"' pom.xml > filename \
    && mv /tmp/app/target/`cat filename` app.jar

# Create final image
FROM azul/zulu-openjdk-debian:8

# Fix for this error: https://github.com/tianon/docker-brew-debian/issues/45
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
    && locale-gen en_US.UTF-8

# ps is needed by nextflow to collect task metrics
RUN apt-get update && apt-get install -y procps

COPY --from=builder /tmp/app/app.jar /app/app.jar
COPY --from=builder /buildinfo /

RUN echo "#!/bin/bash" >> /entrypoint.sh \
    && echo 'CLASS_NAME=$1; shift' >> /entrypoint.sh \
    && echo 'java -Dspark.master=local[*] -cp /app/app.jar ${CLASS_NAME} "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh

