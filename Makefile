.PHONY: test test-fast lint smoke e2e test-services test-bootstrap help
help:
	@echo "make test-fast: verificações locais sem rede/sudo"
	@echo "make e2e: instalação e templates em Ubuntu descartável (Docker/rede)"
	@echo "make test-bootstrap: entrada automática em Ubuntu sem Git/Python/curl"
	@echo "make test-services: PostgreSQL e Portainer isolados (Docker/rede)"
	@echo "make test: testes locais + integração da instalação"
test:
	@./tests/run.sh
test-fast:
	@./tests/run.sh --fast
lint:
	@./tests/lint.sh
smoke:
	@./tests/smoke.sh
e2e:
	@./tests/e2e_docker.sh
test-services:
	@./tests/docker_services.sh

test-bootstrap:
	@./tests/bootstrap_docker.sh
