# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG

ARG GO_IMAGE_NAME
ARG GO_IMAGE_TAG
FROM ${GO_IMAGE_NAME}:${GO_IMAGE_TAG} AS builder

ARG NVM_VERSION
ARG NVM_SHA256_CHECKSUM
ARG IMAGE_NODEJS_VERSION
ARG YARN_VERSION
ARG OPENGIST_VERSION

COPY scripts/start-opengist.sh /scripts/
COPY patches /patches

# hadolint ignore=DL4006,SC3009
RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    && homelab install build-essential git \
    && homelab install-node \
        ${NVM_VERSION:?} \
        ${NVM_SHA256_CHECKSUM:?} \
        ${IMAGE_NODEJS_VERSION:?} \
    # Download opengist repo. \
    && homelab download-git-repo \
        https://github.com/thomiceli/opengist \
        ${OPENGIST_VERSION:?} \
        /root/opengist-build \
    && pushd /root/opengist-build \
    # Apply the patches. \
    && (find /patches -iname *.diff -print0 | sort -z | xargs -0 -r -n 1 patch -p2 -i) \
    && source /opt/nvm/nvm.sh \
    && make clean \
    # This is a workaround to allow building opengist with the latest version of \
    # Node.js. \
    && npm install --package-lock-only \
    # Build opengist. \
    && CGO_ENABLED=0 GOOS=linux make \
    && popd \
    && mkdir -p /output/{bin,scripts} \
    # Copy the build artifacts. \
    && cp /root/opengist-build/opengist /output/bin/ \
    && cp /scripts/* /output/scripts/

FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG OPENGIST_VERSION
ARG PACKAGES_TO_INSTALL

# hadolint ignore=SC3009
RUN --mount=type=bind,target=/opengist-build,from=builder,source=/output \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Install dependencies. \
    && homelab install $PACKAGES_TO_INSTALL \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    && mkdir -p /opt/opengist-${OPENGIST_VERSION:?}/bin /data/opengist/{config,data} \
    && cp /opengist-build/bin/opengist /opt/opengist-${OPENGIST_VERSION:?}/bin/opengist \
    && ln -sf /opt/opengist-${OPENGIST_VERSION:?} /opt/opengist \
    && ln -sf /opt/opengist/bin/opengist /opt/bin/opengist \
    # Copy the start-opengist.sh script. \
    && cp /opengist-build/scripts/start-opengist.sh /opt/opengist/ \
    && ln -sf /opt/opengist/start-opengist.sh /opt/bin/start-opengist \
    # Set up the permissions. \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} \
        /opt/opengist-${OPENGIST_VERSION:?} \
        /opt/opengist \
        /opt/bin/{opengist,start-opengist} \
        /data/opengist \
    # Clean up. \
    && homelab cleanup

# Expose just the HTTP port used by Opengist server.
EXPOSE 6157

# Health check the /healthcheck endpoint.
HEALTHCHECK \
    --start-period=15s --interval=30s --timeout=3s \
    CMD homelab healthcheck-service http://localhost:6157/healthcheck

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-opengist"]
STOPSIGNAL SIGTERM
