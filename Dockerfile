FROM ruby:3.3.5

# Install Node.js (latest LTS version) and npm
RUN curl -sL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt-get update && apt-get install -y --no-install-recommends nodejs

# Install gulp-cli globally using npm
RUN npm install -g gulp-cli

# Install Yarn globally using npm
RUN npm install -g yarn

# Create and set the working directory
RUN mkdir /app
WORKDIR /app

# Copy the Gemfile and Gemfile.lock
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock

# Copy the package.json and yarn.lock
COPY package.json /app/package.json
COPY yarn.lock /app/yarn.lock

# Install dependencies
RUN bundle install
RUN yarn install

# Copy the rest of the application code
COPY . /app
