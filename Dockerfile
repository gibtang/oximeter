# ---- 1. Node.js deps ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --ignore-scripts

# ---- 2. Final image ----
FROM node:22-alpine

# Install nginx and generate config
RUN apk add --no-cache nginx
COPY nginx.conf.template /etc/nginx/conf.d/default.conf

COPY site/ /usr/share/nginx/html/

# Copy Node.js API server and deps
COPY package.json server.mjs ./
COPY --from=deps /app/node_modules ./node_modules

EXPOSE 80
CMD ["sh", "-c", "node server.mjs & nginx -g 'daemon off;'"]
