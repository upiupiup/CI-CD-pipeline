FROM node:14-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build || echo "No build step"

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html || echo "No dist directory"
COPY --from=build /app /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf || echo "No nginx config"

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
