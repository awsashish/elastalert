#FROM alpine:latest as py-ea
FROM python:3.6-alpine as py-ea
ARG ELASTALERT_VERSION=v0.2.0b2
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
# URL from which to download Elastalert.
ARG ELASTALERT_URL=https://github.com/Yelp/elastalert/archive/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/elastalert

WORKDIR /opt

#RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev python3 py3-pip py3-yaml libffi-dev gcc musl-dev wget && \
RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev py3-pip py3-yaml libffi-dev gcc musl-dev wget && \
# Download and unpack Elastalert.
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    pip3 install --upgrade pip setuptools && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Install Elastalert.
# see: https://github.com/Yelp/elastalert/issues/1654
RUN sed -i 's/jira>=1.0.10/jira>=1.0.10,<1.0.15/g' setup.py && \
    python3 setup.py install && \
    pip install -r requirements.txt

FROM node:alpine
LABEL maintainer="BitSensor <dev@bitsensor.io>"
# Set timezone for this container
ENV TZ Etc/UTC

RUN apk add --update --no-cache curl tzdata python3 make libmagic

COPY --from=py-ea /usr/local/lib/python3.6/site-packages /usr/lib/python3.6/site-packages
COPY --from=py-ea /opt/elastalert /opt/elastalert
COPY --from=py-ea /usr/local/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY . /opt/elastalert-server

RUN npm install --production --quiet
COPY config/elastalert.yaml /opt/elastalert/config.yaml
COPY config/elastalert-test.yaml /opt/elastalert/config-test.yaml
COPY config/config.json config/config.json
COPY rule_templates/ /opt/elastalert/rule_templates
COPY elastalert_modules/ /opt/elastalert/elastalert_modules

# Add default rules directory
# Set permission as unpriviledged user (1000:1000), compatible with Kubernetes
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/ \
    && chown -R node:node /opt

#USER node
USER root

EXPOSE 3030
ENTRYPOINT ["npm", "start"]
