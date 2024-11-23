# Pull base image
FROM python:3.10-alpine3.19

# Set working directory
WORKDIR /usr/src/app

# Copy requirement files
COPY requirements.txt .

# Install requirements
RUN apk add curl && \
    apk add unzip
    
# Download requirements
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files to container
COPY . .

# Get new release distribution assets and move to static directory
RUN curl -L https://github.com/alphagov/govuk-frontend/releases/download/v4.5.0/release-v4.5.0.zip > govuk_frontend.zip && \
    unzip -o govuk_frontend.zip -d ./app/static && \
    mv ./app/static/assets/* ./app/static && \
    rm -rf ./app/static/assets && \
    rm -rf ./govuk_frontend.zip

ENV PATH="/usr/src/app:${PATH}"

# Expose container port
EXPOSE 5000

# Execute application
CMD ["python3", "-m", "flask", "run", "-h", "0.0.0.0", "-p", "5000"]