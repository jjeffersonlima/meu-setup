"""
Exemplo de Script de Automação com Python e uv
==============================================
Para rodar este script:
    uv run main.py
Para adicionar uma dependência (exemplo: requests):
    uv add requests
"""

import sys
import datetime

def main():
    agora = datetime.datetime.now().strftime("%d/%m/%Y às %H:%M:%S")
    print(f"🚀 Automação iniciada em {agora}")
    print(f"🐍 Rodando com Python {sys.version.split()[0]}")
    print("✔ Tudo pronto para programar sua lógica de automação!")

if __name__ == "__main__":
    main()
