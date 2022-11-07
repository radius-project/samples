FROM node:18-buster as BUILD
WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci && npm cache clean --force

COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /usr/src/app

COPY --from=BUILD /usr/src/app/dist ./dist
COPY --from=BUILD /usr/src/app/node_modules ./node_modules

EXPOSE 3000
CMD [ "node", "dist/server.js" ]