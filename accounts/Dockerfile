FROM node:8.14.0
LABEL maintainer="iwinoto@au1.ibm.com"

WORKDIR /app
# Install app dependencies
COPY . /app
RUN cd /app; npm install; npm prune --production
ENV NODE_ENV production
ENV PORT 3400

EXPOSE 3400
CMD [ "npm","start" ]
