# Stand-in for the tutor's sarojsanyasi/dso202-frontend:1.1 (not yet published
# on Docker Hub when Assignment 4 was done). Built locally and loaded into kind.
# Release note honoured: "The page header displays the release number. No other change."
FROM sarojsanyasi/dso202-frontend:1.0
LABEL org.opencontainers.image.version="1.1" \
      org.opencontainers.image.description="LOCAL STAND-IN for tutor image 1.1 (DSO202 A4)"
USER root
RUN sed -i 's#<h1>Field&nbsp;Log</h1>#<h1>Field\&nbsp;Log <small class="release">v1.1</small></h1>#' /usr/share/nginx/html/index.html \
 && grep -q 'v1.1' /usr/share/nginx/html/index.html
USER nginx
