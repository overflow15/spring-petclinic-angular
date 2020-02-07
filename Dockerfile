FROM nginx:1.17.8-alpine
VOLUME /tmp
COPY spring-petclinic-angular-8.0.1.tgz /tmp
RUN tar -xzvf /tmp/spring-petclinic-angular-8.0.1.tgz -C /tmp && cp -Rf /tmp/package/dist/* /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
