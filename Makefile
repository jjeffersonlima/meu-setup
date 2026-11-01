.PHONY: test test-fast lint smoke e2e help

help:
	@echo "Comandos disponíveis no meu-setup:"
	@echo "  make test        Executa todas as camadas: Lint + Smoke + E2E Docker"
	@echo "  make test-fast   Executa validações rápidas locais (Lint + Smoke, ~2s)"
	@echo "  make lint        Executa validação de sintaxe e ShellCheck"
	@echo "  make smoke       Executa testes de interface CLI e módulos isolados"
	@echo "  make e2e         Executa testes End-to-End determinísticos no Docker"

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
