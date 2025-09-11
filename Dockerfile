ARG UE_IMAGE_TAG=dev-5.6.1
# First image is used to build your project inside a container
FROM ghcr.io/epicgames/unreal-engine:${UE_IMAGE_TAG} AS builder

# Expose UDP port (still need to publish!)
EXPOSE 7777/udp

# Copy source code
COPY --chown=ue4:ue4 .. /tmp/project

ARG SERVER_CONFIG
ARG PROJECT_FILE_NAME
ARG UE_BUILD_ARGS

# Clean & build dedicated server for Linux
RUN /home/ue4/UnrealEngine/Engine/Build/BatchFiles/RunUAT.sh BuildCookRun \
    -serverconfig=${SERVER_CONFIG} \
    -project=/tmp/project/${PROJECT_FILE_NAME}.uproject \
    -utf8output -nodebuginfo -allmaps -noP4 -cook -ddc=NoZenLocalFallback -build -stage -prereqs -pak -package -archive \
    -archivedirectory=/tmp/project/Packaged \
    -platform=Linux -server -noclient \
    ${UE_BUILD_ARGS}

# Second image is used to run the project build
FROM ubuntu:22.04 AS runtime

ARG TARGET_FILE_NAME=
ENV TARGET_FILE_NAME=${TARGET_FILE_NAME}

# Specify container command for later (main process)
CMD ["/home/ue4/project/StartServer.sh"]

# Install runtime dependencies
RUN apt-get update && \
    apt-get install openssh-server sudo jq curl -y && \
    apt-get clean && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

# Create user
RUN useradd ue4
USER ue4

ARG BUILDUTILS_FOLDER
# Copy build and runtime files in the runtime container
COPY --from=builder --chown=ue4:ue4 /tmp/project/Packaged/LinuxServer /home/ue4/project
COPY --chown=ue4:ue4 ./${BUILDUTILS_FOLDER}/StartServer.sh /home/ue4/project/StartServer.sh
RUN sed -i 's/\r$//' /home/ue4/project/StartServer.sh
