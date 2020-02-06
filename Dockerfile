FROM nginx:1.17.8-alpine
VOLUME /tmp
COPY spring-petclinic-angular-8.0.1.tgz /tmp
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
