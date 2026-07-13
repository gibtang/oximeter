# ---- 1. Node.js API server deps ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --ignore-scripts

# ---- 2. Final image ----
FROM nginx:alpine
COPY nginx.conf.template /tmp/default.conf.template
RUN sed 's|__LEAD_CAPTURE_URL__|http://127.0.0.1:3000/api/early-access|' \
    /tmp/default.conf.template > /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/

# Copy Node.js API server and deps
COPY package.json server.mjs ./
COPY --from=deps /app/node_modules ./node_modules

EXPOSE 80
CMD ["sh", "-c", "node server.mjs & nginx -g 'daemon off;'"]
