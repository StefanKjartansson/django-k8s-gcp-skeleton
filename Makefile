clean:
	find . -iname "__pycache__" -exec rm -rf {} +

bootstrap: venv
	./env/bin/pip install -r dev-requirements.txt
	./env/bin/pip install -r requirements.txt

venv:
	python3.6 -m venv env
	./env/bin/pip install --upgrade setuptools pip wheel

test:
	./env/bin/py.test -x -c pytest.ini --create-db

coverage:
	./env/bin/coverage report
