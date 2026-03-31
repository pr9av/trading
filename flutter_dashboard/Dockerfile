# Stage 1: Build
FROM debian:bullseye-slim AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Enable web
RUN flutter config --enable-web

WORKDIR /app
COPY . .

# Get dependencies and build web
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Runtime
FROM nginx:alpine

# Copy build files to nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Custom nginx config to handle client-side routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
