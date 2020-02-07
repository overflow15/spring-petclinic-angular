FROM nginx:1.17.8-alpine
VOLUME /tmp
COPY spring-petclinic-angular-8.0.1.tgz /tmp
CMD tar -xzvf spring-petclinic-angular-8.0.1.tgz /tmp/
CMD cp -R /tmp/package/dist/* /var/www/html/
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
