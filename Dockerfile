FROM nginx:1.17.8-alpine
VOLUME /tmp
COPY application_package /tmp
RUN tar -xzvf /tmp/application_package -C /tmp && cp -Rf /tmp/package/dist/* /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
