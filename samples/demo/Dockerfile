FROM node:20-bookworm AS build
WORKDIR /usr/src/app

COPY package.json package-lock.json ./
COPY client/package.json client/package-lock.json ./client/
RUN npm ci && npm cache clean --force
RUN cd client && npm ci && npm cache clean --force

COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /usr/src/app

COPY --from=BUILD /usr/src/app/dist ./dist
COPY --from=BUILD /usr/src/app/node_modules ./node_modules

EXPOSE 3000
ENV PORT=3000
CMD [ "node", "dist/main.js" ]
