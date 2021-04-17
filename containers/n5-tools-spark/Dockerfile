# Staged build using builder container
FROM janeliascicomp/builder:1.2.1 as builder
ARG GIT_TAG=master

# Checkout and build the code
WORKDIR /tmp/app
RUN git clone --branch $GIT_TAG --depth 1 https://github.com/saalfeldlab/n5-spark . \
    && git submodule update --init --recursive \
    && /usr/local/bin/buildinfo.sh \
    && mvn package -P fatjar,spark-provided

# Find the built jar, based on the version in the pom file
RUN xq -r '.project.artifactId+"-"+.project.version+".jar"' pom.xml > filename \
    && mv /tmp/app/target/`cat filename` app.jar

# Create final image
FROM multifish/spark:3.0.1-hadoop3.2

WORKDIR /app
COPY --from=builder /tmp/app/app.jar /app/app.jar
COPY --from=builder /buildinfo /

