FROM nginx:1.29-alpine


RUN mkdir -p /var/cache/nginx /var/run /var/log/nginx \
    && chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx

COPY --chown=nginx:nginx nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx default.conf /etc/nginx/conf.d/default.conf

COPY --chown=nginx:nginx \
    index.html \
    /usr/share/nginx/html/

USER nginx

EXPOSE 80
