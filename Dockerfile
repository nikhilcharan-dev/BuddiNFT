# Use a stable Node image
FROM node:20-bullseye

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Copy package descriptors and install deps (cached layer)
COPY package.json package-lock.json* ./
RUN npm ci --silent

# Copy rest of the project
COPY . .

# Precompile contracts during build to catch compile errors early
RUN npx hardhat compile

# Run tests by default (container will exit with test rc)
CMD ["npx", "hardhat", "test", "--no-compile"]
