"""Consulta MCP real contra o servidor efêmero da integração, sem LLM remoto."""
import json
import os
from pathlib import Path
import urllib.request


def main():
    token = (Path(os.environ['HOME']) / '.local/share/ai-memory/auth-tokens/default').read_text().strip()
    headers = {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json',
               'Accept': 'application/json, text/event-stream'}
    sequence = 0

    def rpc(method, params):
        nonlocal sequence
        sequence += 1
        payload = {'jsonrpc': '2.0', 'id': sequence, 'method': method, 'params': params}
        request = urllib.request.Request('http://127.0.0.1:49374/mcp',
                                         json.dumps(payload).encode(), headers)
        with urllib.request.urlopen(request, timeout=30) as response:
            session = response.headers.get('Mcp-Session-Id')
            if session:
                headers['Mcp-Session-Id'] = session
            body = response.read().decode()
            if response.headers.get('Content-Type', '').startswith('text/event-stream'):
                messages = [json.loads(line[6:]) for line in body.splitlines() if line.startswith('data: ')]
                result = next(item for item in messages if item.get('id') == sequence)
            else:
                result = json.loads(body)
        assert 'error' not in result, result
        return result['result']

    rpc('initialize', {'protocolVersion': '2025-03-26', 'capabilities': {},
                       'clientInfo': {'name': 'meu-setup-integration', 'version': '1'}})
    headers['MCP-Protocol-Version'] = '2025-03-26'
    catalog = rpc('tools/list', {})
    assert any(tool['name'] == 'memory_query' for tool in catalog['tools'])
    for project, expected in [('fixture-a', True), ('fixture-b', False)]:
        result = rpc('tools/call', {'name': 'memory_query', 'arguments': {
            'workspace': 'integration', 'project': project,
            'query': 'mcp-preservation-fixture', 'limit': 5}})
        assert not result.get('isError'), result
        found = 'mcp-preservation-fixture' in json.dumps(result)
        assert found == expected, f'Isolamento incorreto para {project}: {result}'
    print('MCP: busca real e isolamento entre projetos aprovados.')


if __name__ == '__main__':
    main()
