FROM dart:stable AS build

# Resolve dependencies first so they stay cached between source changes.
WORKDIR /app
COPY . .
WORKDIR /app/example/color_extractor_server

# Get dependencies
RUN dart pub get
# Build a self-contained AOT binary.
RUN dart compile exe bin/color_extractor_server.dart -o bin/server

# ---------------------------------------------------------------------------
# Runtime stage: minimal image containing only the compiled binary
# ---------------------------------------------------------------------------
FROM scratch

# Copy the native binary produced in the build stage.
COPY --from=build /runtime/ /
COPY --from=build /app/example/color_extractor_server/bin/server /app/bin/server

# The shelf server listens on this port.
ENV PORT=8080
EXPOSE 8080

# Run as a non-root user for a smaller security surface.
USER 65534:65534

ENTRYPOINT ["/app/bin/server"]
