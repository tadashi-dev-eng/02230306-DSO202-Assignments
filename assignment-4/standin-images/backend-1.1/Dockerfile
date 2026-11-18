# Stand-in for the tutor's sarojsanyasi/dso202-backend:1.1 (not yet published).
# Release note: "Internal refactoring of configuration loading. The API is unchanged."
FROM sarojsanyasi/dso202-backend:1.0
LABEL org.opencontainers.image.version="1.1" \
      org.opencontainers.image.description="LOCAL STAND-IN for tutor image 1.1 (DSO202 A4)"
COPY --chown=app:app config-check.js /app/src/config-check.js
CMD ["node", "-r", "./src/config-check.js", "src/server.js"]
