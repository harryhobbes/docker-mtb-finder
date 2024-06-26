# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

ARG PYTHON_VERSION=3.8.5
FROM --platform=linux/amd64 python:${PYTHON_VERSION}-slim as base

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr to avoid situations where
# the application crashes without emitting any logs due to buffering.
ENV PYTHONUNBUFFERED=1

RUN apt-get -y update && apt-get -y install git

WORKDIR /web/mtb-finder

ADD https://api.github.com/repos/harryhobbes/mtb-finder/git/refs/heads/main ../version.json
RUN git clone https://github.com/harryhobbes/mtb-finder.git .

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/web/mtb-finder/userdata" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /root/.cache/pip to speed up subsequent builds.
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install --upgrade pip 
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install -r requirements.txt

# Install Chromium. Could be a better way eg. Chromium docker container
# https://github.com/linuxserver/docker-chromium
#RUN apt-get update && apt-get install chromium -y --no-install-recommends

# Install the Google Chrome binary
# Adding trusting keys to apt for repositories
RUN apt-get -y update && apt-get install -y gnupg2 && apt-get install -y wget 

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -

# Adding Google Chrome to the repositories
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'

# Updating apt to see and install Google Chrome
RUN apt-get -y update && apt-get install -y google-chrome-stable

# Switch to the non-privileged user to run the application.
USER appuser

# Expose the port that the application listens on.
EXPOSE 9050

# Run the application.
CMD ["gunicorn", "--bind", "0.0.0.0:9050", "app.__init__:create_app()"]