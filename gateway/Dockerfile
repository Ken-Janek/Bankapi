FROM node:20-bookworm-slim
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY index.js swagger.json ./
COPY keys ./keys
EXPOSE 3000
CMD ["node", "index.js"]
