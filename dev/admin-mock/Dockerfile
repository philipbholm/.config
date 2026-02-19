FROM node:24-slim AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY tsconfig.json ./
COPY src/ src/
RUN npx tsc

FROM node:24-slim
WORKDIR /app
COPY --from=build /app/package.json /app/package-lock.json* ./
RUN npm install --omit=dev
COPY --from=build /app/build/ build/
COPY api/ api/
EXPOSE 4000 50051
CMD ["node", "build/index.js"]
