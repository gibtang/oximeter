FROM nginx:alpine
ARG LEAD_CAPTURE_URL=https://check-mcc.sg/api/early-access
COPY nginx.conf.template /tmp/default.conf.template
RUN sed "s|__LEAD_CAPTURE_URL__|${LEAD_CAPTURE_URL}|" /tmp/default.conf.template > /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
EXPOSE 80
