# Plano de correção do meu-setup

Data: 5 de novembro de 2026.

Status: correções implementadas e aplicadas nesta máquina. A aplicação na segunda máquina será manual posteriormente, conforme orientação do usuário. Evidências e instruções em [docs/IMPLANTACAO.md](docs/IMPLANTACAO.md).

## Objetivo

Oferecer um ambiente pessoal de desenvolvimento que um estudante consiga instalar, reparar e usar com poucos comandos, mensagens claras e tempo de resposta curto. Aproveitar Bash, a divisão em módulos e as ferramentas existentes. A prioridade é permitir estudar e criar projetos com confiança.

A reinstalação deverá corrigir a configuração ativa deixada por versões anteriores do meu-setup. Isso exige uma migração das instalações existentes, além da correção do instalador para máquinas novas.

## O que significa uma reinstalação sem resíduos

Ao concluir com sucesso, deverá existir uma única configuração ativa do projeto: sem aliases antigos, inicializações repetidas, atalhos quebrados, cópias obsoletas dos utilitários ou completions inválidos reconhecidos como pertencentes ao setup.

| Item | Tratamento planejado |
| --- | --- |
| Blocos antigos do meu-setup no Bash | Reconhecer formatos históricos, substituir pela configuração atual e eliminar duplicações conhecidas. |
| Utilitários copiados por versões antigas | Reconhecer pelo histórico/conteúdo e migrar para o mecanismo atual, após backup. |
| Links antigos ou quebrados | Reconectar ao checkout correto; verificar também arquivos em caminhos conhecidos que estejam ocultando o comando atual. |
| Caches e arquivos temporários do próprio setup | Regenerar quando necessários e remover os que comprovadamente ficaram obsoletos. |
| Configurações WSL, prompt e Git | Corrigir as entradas gerenciadas pelo projeto, preservando configurações pessoais e reconhecendo alterações feitas por versões anteriores. |
| Ferramentas instaladas e funcionais | Reaproveitar; reparar ou substituir uma instalação gerenciada quando estiver inválida ou incompatível. |
| Versões Node/Python usadas por projetos | Preservar; uma versão antiga pode continuar necessária a um projeto de estudo. |
| Projetos, arquivos pessoais, identidade Git e chaves SSH | Preservar. |
| Bancos, volumes e dados do Portainer | Preservar na reinstalação e no reparo comum. |
| Arquivos sem identificação segura de origem | Mostrar como pendência, sem declarar limpeza completa e sem apagar por suposição. |
| Backups de recuperação | Guardar em local identificado, fora da configuração ativa, com política de retenção clara. |

Limite: a reinstalação não consegue reconstruir conteúdo que uma versão anterior já apagou quando não existe backup. Se houver cópias de segurança, comparar e recuperar seletivamente os valores perdidos; restaurar um arquivo inteiro pode reintroduzir os erros antigos. A migração não fará remoção geral de pacotes, caches de projetos ou pastas pessoais.

## Etapa 1 — Preparar o diagnóstico e a recuperação

**Execução**

- Inventariar cada máquina separadamente: revisão do setup, distribuição, recursos WSL, caminhos e versões das ferramentas, arquivos gerenciados e situação do Docker.
- Levantar as assinaturas das instalações antigas pelo histórico Git. Já foi identificada a transição de cópias de utilitários para links simbólicos.
- Criar exemplos de instalações antigas para testes, sem incluir credenciais ou dados pessoais.
- Definir uma lista explícita dos arquivos, blocos e recursos que o setup administra.
- Implementar backup verificado antes da primeira alteração de cada configuração, com registro de origem e caminho de recuperação. Se o backup falhar, não modificar aquele arquivo.
- Registrar uma medição inicial simples em cada máquina para comparar inicialização do shell e tarefas comuns depois do reparo.

**Motivo:** as duas máquinas podem ter versões e configurações diferentes. Precisamos reconhecer o estado real e ter como desfazer alterações de configuração.

**Critério de conclusão:** o levantamento mostra o que será alterado e preservado; uma restauração de configuração foi exercitada em ambiente temporário.

## Etapa 2 — Corrigir erros silenciosos e operações destrutivas

**Execução**

- Propagar falhas do instalador e do APT. Sucesso só será informado após a verificação correspondente.
- Parar etapas dependentes quando um pré-requisito falhar; continuar verificações independentes quando isso ajudar o diagnóstico.
- Apresentar, ao final, os estados «pronto», «opcional não escolhido», «requer reinício» e «falhou», com a próxima ação necessária.
- Impedir que o gerador substitua arquivos em destinos já existentes. Em falhas, preservar o trabalho anterior e explicar o estado de uma pasta recém-criada.
- Fazer o reset comum do Portainer preservar o volume. Uma eventual exclusão de dados deve ser uma ação separada, com nome e confirmação explícitos.
- Manter o setup token no primeiro acesso e orientar sua obtenção quando necessário, especialmente em modo LAN. O token protege contra outra pessoa assumir uma instância nova. [Documentação do Portainer](https://docs.portainer.io/faqs/installing/setup-token).
- Retirar a limpeza de containers e caches do fluxo padrão de atualização, inclusive com `--yes`. Limpeza será uma opção separada. O `docker system prune` pode apagar containers parados e cache de build. [Documentação do Docker](https://docs.docker.com/reference/cli/docker/system/prune/).
- Fazer `--help` funcionar sem criar arquivos, iniciar serviços ou solicitar privilégios. O diagnóstico deve ser de leitura, sem pedir senha inesperadamente.
- Adicionar os testes de regressão correspondentes junto de cada correção.

**Motivo:** para um iniciante, uma mensagem de sucesso incorreta ou uma perda de dados pode gerar horas de confusão. Esta etapa protege o uso cotidiano antes da migração.

**Critério de conclusão:** falhas simuladas retornam erro real; destinos existentes e dados persistentes permanecem preservados.

## Etapa 3 — Construir a reinstalação que repara versões antigas

**Execução**

- Usar o mesmo ponto de entrada, `./install.sh`, para máquinas novas e existentes. Detectar instalação anterior e recomendar reparo automaticamente.
- Executar as migrações conhecidas nas instalações existentes, mesmo quando os executáveis já estiverem presentes. «Instalado» não deverá significar «configuração correta».
- Substituir os blocos históricos reconhecidos por uma configuração gerenciada única, preferencialmente mantida em arquivo próprio e carregada uma vez pelo Bash.
- Reconectar utilitários copiados ou links quebrados, corrigir entradas gerenciadas repetidas no PATH e regenerar completions inválidos.
- Tratar blocos incompletos com cuidado: não usar uma remoção que possa consumir conteúdo pessoal até o fim do arquivo. Registrar ambiguidades como pendência.
- Editar `wsl.conf` e `.wslconfig` por seção e chave. Consolidar duplicações reconhecidas do setup e preservar limites pessoais de memória, CPU, swap e outras opções.
- Identificar o perfil Windows correto. Não escolher automaticamente o primeiro diretório de usuário disponível.
- Aplicar somente recursos WSL compatíveis. Deixar mudanças de rede avançadas fora da instalação padrão quando não forem necessárias para o objetivo.
- Preservar personalizações de Starship e Git; substituir automaticamente configurações antigas apenas quando sua origem for reconhecida ou houver uma migração inequívoca.
- Fazer escritas por arquivo temporário validado antes da substituição, respeitando permissões. Registrar uma migração como concluída somente após sua verificação.
- Impedir duas instalações simultâneas. Se houver interrupção, permitir nova execução com reavaliação do estado e sem duplicar alterações.
- Manter um registro pequeno de versão da configuração, arquivos administrados e migrações realizadas. A verificação do estado real continuará necessária mesmo quando o registro indicar sucesso.
- Informar quando for necessário reiniciar o WSL, sem fechar automaticamente as sessões em uso. A configuração é aplicada na inicialização e `wsl --shutdown` encerra todas as distribuições em execução. [Documentação da Microsoft](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

**Motivo:** essa é a etapa que atende diretamente às duas instalações já existentes. Reinstalar precisa substituir os erros conhecidos, além de instalar componentes ausentes.

**Critério de conclusão:** uma instalação antiga reconhecida converge para a configuração atual; uma segunda e uma terceira execução não acrescentam configurações, backups desnecessários ou novos reparos. Registros de execução podem ser atualizados. Pendências desconhecidas impedem declarar limpeza completa.

## Etapa 4 — Simplificar o uso para estudar e criar projetos

**Execução**

- Oferecer uma escolha recomendada explicada por finalidade e manter a personalização disponível. As escolhas anteriores serão lembradas nas reinstalações.
- Nas máquinas existentes, preservar os componentes selecionados, sem desinstalar ferramentas porque uma nova recomendação mudou.
- Manter os atalhos familiares: `novo`, `doctor`, `atualizar`, `lg`, `ld` e `portainer`.
- Corrigir os atalhos que precisam encaminhar argumentos, incluindo `code`, `open` e listagens com fallback. Fazer `novo-python` abrir diretamente o fluxo Python.
- Dar aos projetos gerados um único comando de execução indicado corretamente no README e na mensagem final.
- Para automações Python de estudo, adotar um template simples e explícito com `main.py`, independente de mudanças no padrão do uv. O uv permite desabilitar o empacotamento com `--no-package`; essa opção será validada nas versões suportadas. [Documentação do uv](https://docs.astral.sh/uv/concepts/projects/init/).
- Para Node, entregar scripts de execução e verificação no `package.json`; confirmar a instalação das dependências antes de declarar o projeto pronto.
- Para Astro, verificar os pré-requisitos e validar criação e build nos testes de integração.
- Para Docker, evitar nomes globais fixos de containers que causem conflito entre projetos. Explicar quando portas padrão já estiverem ocupadas.
- Diagnosticar apenas o que foi escolhido: uma ferramenta opcional não instalada não deve aparecer como defeito.
- Exibir instruções curtas e acionáveis, como «abra um terminal novo» ou «a instalação parou por falta de conexão; execute novamente».

**Motivo:** a complexidade deve ficar no instalador. O uso diário precisa permitir criar, executar e entender um projeto sem memorizar detalhes das ferramentas.

**Critério de conclusão:** seguindo apenas as instruções exibidas, é possível criar e executar um exemplo de cada tipo escolhido, sem correções manuais ocultas.

## Etapa 5 — Tornar instalação e atualização rápidas e previsíveis

**Execução**

- Compartilhar as rotinas de detecção, instalação e verificação entre instalador, atualizador e diagnóstico.
- Manter uma relação pequena de versões testadas para os componentes administrados pelo setup. Mudanças dessa relação serão validadas antes de uma nova versão do projeto.
- Validar compatibilidade e caminhos reais de Node, Python e Compose, evitando aceitar apenas a presença de um comando ou um executável Windows encontrado pelo PATH.
- Reparar executáveis inválidos; evitar reinstalar ferramentas saudáveis ou trocar versões de projetos existentes sem necessidade.
- Aplicar prazo e tentativas limitadas a downloads. Instalar arquivos baixados somente depois das verificações disponíveis no fornecedor.
- Reaproveitar downloads e caches válidos. Atualizar apenas quando necessário e regenerar completions quando a ferramenta mudar.
- Manter o Portainer sob demanda. Tratar a inicialização do Docker como uma escolha explícita de conveniência, sem prometer consumo zero enquanto o serviço estiver ativo.
- Garantir que atualizações do repositório não descartem alterações locais nem mudem inadvertidamente a branch de trabalho.
- Remover temporários criados pela própria operação e limitar o crescimento dos logs. Organizar backups para recuperação, sem carregá-los como configuração ativa.

**Motivo:** para uso pessoal, simplicidade e reaproveitamento trazem mais benefício que uma reestruturação complexa ou paralelização prematura. Caches úteis também contribuem para a rapidez.

**Critério de conclusão:** reinstalar reaproveita componentes saudáveis, uma falha de rede termina com mensagem útil e o bloco de inicialização do shell não apresenta regressão relevante em relação à medição da mesma máquina.

## Etapa 6 — Validar instalação nova, migração e uso real

Os testes relevantes acompanharão as etapas anteriores. Esta etapa reúne a validação de liberação.

| Cenário | Resultado exigido |
| --- | --- |
| Instalação nova | Ferramentas selecionadas funcionam e o diagnóstico corresponde à realidade. |
| Migração de formatos históricos | Cópias antigas, blocos reconhecidos e atalhos inválidos são corrigidos, sem alterar conteúdo pessoal. |
| Reinstalação repetida | Configuração ativa permanece estável e sem duplicações. |
| Falha de rede ou APT | Retorno de erro real; nenhuma aprovação fictícia; reexecução possível. |
| Interrupção no meio | Configurações válidas são preservadas ou recuperáveis e a próxima execução consegue continuar. |
| Projeto já existente | Nenhum arquivo anterior é substituído. |
| Atalhos com argumentos | O caminho chega ao programa correto, inclusive quando contém espaços. |
| Projetos gerados | Python e Node executam, Astro passa pelo build e o Compose é validado; serviços Docker são exercitados no ambiente de integração apropriado. |
| Portainer | Reparação preserva dados; primeiro acesso e modos de rede são verificados. |
| Componentes opcionais | O diagnóstico respeita o perfil escolhido. |

- Testes rápidos devem funcionar sem baixar dependências de projetos, usando simulações para falhas e efeitos no sistema.
- Testes com downloads e serviços ficam na integração, com prazo e identificação claros.
- ShellCheck será obrigatório na CI. Uma verificação não executada será reportada como tal.
- Remover aprovações incondicionais. O resultado do diagnóstico deverá influenciar o teste corretamente.
- Usar containers para os casos que conseguem reproduzir e uma validação WSL real para systemd, integração Windows, reinício e permissões. Um container comum não será apresentado como comprovação integral do WSL.

**Motivo:** a regressão mais importante é a que atrapalha o estudo ou quebra uma instalação existente. Os testes devem demonstrar esses resultados.

**Critério de conclusão:** as verificações obrigatórias passaram; limitações estão registradas e nenhuma falha foi convertida em sucesso para liberar a versão.

## Etapa 7 — Migrar as duas máquinas e entregar um guia curto

**Execução**

1. Identificar uma revisão de liberação que tenha passado pelas etapas anteriores e preparar instruções exatas para obtê-la.
2. Escolher como piloto a máquina em que uma eventual interrupção cause menos impacto.
3. Fazer inventário e backup nessa máquina; executar a instalação em modo de reparo.
4. Abrir uma sessão nova e, quando necessário, reiniciar o WSL em momento apropriado.
5. Verificar os atalhos, os projetos e os dados já existentes; criar um projeto de teste e repetir o instalador para confirmar estabilidade.
6. Conferir o relatório de migração, incluindo resíduos conhecidos removidos e eventuais pendências. Só avançar após resolver problemas do piloto.
7. Aplicar a mesma revisão à segunda máquina, com inventário e backup próprios. Preservar diferenças legítimas de hardware, sistema e preferências.
8. Entregar um guia com instalação/reparo, criação de projeto, execução, atualização, diagnóstico e recuperação de configurações.

O instalador será capaz de fazer a maior parte do reparo automaticamente. As ações que dependem de uma sessão Windows ou da outra máquina serão indicadas claramente durante a aplicação.

**Recuperação:** se a migração falhar, interromper a implantação na segunda máquina, restaurar as configurações afetadas e usar a revisão anterior do setup quando apropriado. Esse procedimento não promete desfazer integralmente atualizações de pacotes do sistema ou recuperar dados já apagados anteriormente.

**Motivo:** validar em uma máquina primeiro reduz a chance de interromper seu ambiente de estudo nas duas ao mesmo tempo.

**Critério de conclusão:** ambas usam a revisão corrigida; o uso diário funciona; as configurações antigas reconhecidas deixaram de estar ativas; os dados anteriores foram preservados e as pendências foram resolvidas ou explicitamente registradas.

## Organização da execução

Implementar na ordem apresentada, com alterações revisáveis por etapa e verificação correspondente. A etapa de testes começa junto das correções, e a aplicação às máquinas acontece somente após a validação de liberação.

O escopo permanece pessoal: manter a arquitetura atual, os comandos conhecidos e as ferramentas úteis. Evitar um novo sistema de plugins, serviço permanente de gerenciamento ou troca ampla de tecnologias. O resultado esperado é uma reinstalação simples que reconheça e repare as versões antigas e deixe o ambiente pronto para estudar e desenvolver.
