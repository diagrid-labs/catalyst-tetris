ARG PYTHON_VERSION=3.12.1

FROM python:${PYTHON_VERSION}
WORKDIR /users
RUN pip3 install --upgrade pip
RUN pip3 install grpcio
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
COPY . .

CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0"]
