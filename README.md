# SBSeg-demo-Autocorrelacao-Para-Taxa-de-Atualizacao-Ataque-Tempest

Complemento prático para o artigo: Estimação Rápida de Taxa de Quadros em Ataques de Canais Laterais Eletromagnéticos de Sistemas Públicos.

Este repositório contém os scripts em GNU Octave para testar e validar o cálculo da Autocorrelação Linear Discreta (DLA) e da Autocorrelação Linear Discreta Rápida (F-DLA) apresentados na pesquisa.

## Pré-requisitos
A execução exige o **GNU Octave** e o pacote de processamento de sinais. Como o pacote `signal` possui dependências, instale primeiro o pacote `control`. No terminal do Octave, execute os comandos abaixo:

```octave
pkg install -forge control
pkg install -forge signal
pkg load signal
```

## Estrutura de Dados
Os dados de entrada são amostras complexas de sinal de vídeo capturadas por SDR (*interleaved float32 I,Q*). Os arquivos `.dat` encontram-se compactados em formato `.bz2` no subdiretório `dataset/raw/`. 

## Instruções para Teste
Os algoritmos operam separadamente em seus respectivos scripts (`dla.m` e `fdla.m`). Para testar os métodos descritos no artigo:

1. **Preparação dos Dados:** Navegue até o diretório `dataset/raw/` e descompacte um arquivo de cenário para teste (por exemplo, extraia `23.dat` a partir de `23.dat.bz2`). Coloque o arquivo `.dat` no mesmo diretório dos scripts ou anote seu caminho absoluto.
2. **Configuração dos Parâmetros:** Abra os códigos-fonte `dla.m` e `fdla.m` em um editor. Modifique diretamente (*hardcoded*) as seguintes variáveis localizadas no início dos arquivos:
   - `filename`: Caminho para o arquivo `.dat` (ex: `filename='23.dat';`).
   - `N`: Número de amostras a serem lidas para análise.
   - `fs`: Taxa de amostragem da captura em Hz (ex: `54e6`).
3. **Execução:** No ambiente do GNU Octave, execute os scripts individualmente para analisar a diferença de desempenho e extração de parâmetros:
   - Execute o comando `dla` para rodar o algoritmo convencional (complexidade $O(N \log N)$).
   - Execute o comando `fdla` para rodar o algoritmo otimizado proposto no artigo (complexidade $O(N)$).
4. **Análise de Resultados:** A execução informará no terminal a taxa de quadros (FRR) identificada, o atraso (*lag*) correspondente e gerará um gráfico com a autocorrelação normalizada do sinal.

## Licença
Distribuído sob a licença MIT.
