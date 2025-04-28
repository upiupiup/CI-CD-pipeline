# Run on master node
FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 80