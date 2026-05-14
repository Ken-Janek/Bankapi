FROM node:20-bookworm-slim
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY index.js .
COPY keys ./keys
EXPOSE 3003
CMD ["node", "index.js"]
