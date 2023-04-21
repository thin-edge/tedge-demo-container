FROM python:3.10
WORKDIR /usr/src/app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

ENV CONNECTOR_TEDGE_HOST=tedge
ENV CONNECTOR_TEDGE_API=http://tedge:8000

COPY . .
CMD [ "python", "-m", "connector" ]