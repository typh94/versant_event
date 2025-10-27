# Multi-stage Dockerfile to build and serve the Flutter Web app on Railway

# ---------- Build stage: Flutter ----------
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Enable Flutter web just in case the image doesn't have it enabled
RUN flutter config --enable-web

# Copy only the files needed to resolve dependencies first (better caching)
# Avoid copying pubspec.lock to prevent SDK/version mismatch in container
COPY pubspec.yaml ./
# Copy local path dependency so `flutter pub get` can resolve it
COPY docx_template ./docx_template
RUN flutter pub get

# Now copy the rest of the source
COPY . .

# Build the Flutter web app (release)
# --no-tree-shake-icons is useful if you rely on dynamically referenced icons
RUN flutter build web --release --no-tree-shake-icons

# ---------- Runtime stage: Node.js + Express static server ----------
FROM node:20-alpine AS runner
WORKDIR /app

# Copy the built web assets
COPY --from=build /app/build/web ./build

# Copy the Node server files
COPY package.json package-lock.json* ./
COPY server.js ./

# Install only production dependencies
RUN npm ci --omit=dev || npm install --omit=dev

ENV NODE_ENV=production
# Railway sets the PORT env var. Default to 3000 for local runs.
ENV PORT=3000
EXPOSE 3000

# Start the static file server
CMD ["node", "server.js"]
