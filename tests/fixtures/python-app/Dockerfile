FROM python:3.13-slim
# Security fixes newer than the base image, then no pip at run time: nothing installs packages
# there, and its vendored libraries (urllib3, msgpack...) are what Trivy reports.
RUN apt-get update && apt-get -y upgrade && rm -rf /var/lib/apt/lists/* \
 && python -m pip uninstall -y pip \
 && useradd --system --uid 10001 --no-create-home app
WORKDIR /app
COPY app ./app
USER 10001
EXPOSE 8000
CMD ["python", "-m", "app.main"]
