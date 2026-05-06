FROM services/common:docker-base

COPY requirements.txt .
RUN uv pip install -r requirements.txt

COPY app/ .

EXPOSE 5000

CMD ["uv", "run", "python", "main.py"]