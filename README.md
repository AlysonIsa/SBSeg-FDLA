# SBSeg - Estimação Rápida de Taxa de Quadros em Ataques de Canais Laterais Eletromagnéticos de Sistemas Públicos.

Complemento prático para o artigo [1], incluindo acessórios para replicação de resultados não reportados no artigo por limitações de espaço. Os experimentos tem como objetivo testar e validar o cálculo da Autocorrelação Linear Discreta (DLA) e da Autocorrelação Linear Discreta Rápida (F-DLA) apresentados na pesquisa.

[1] ISALUSKI, Alyson; TEODORO, Leonardo; V. CARDOSO, Kleber; OLIVEIRA-JR, Antonio; QUEIROZ, Saulo. Estimação Rápida de Taxa de Quadros em Ataques de Canais Laterais Eletromagnéticos de Sistemas Públicos. In: SIMPÓSIO BRASILEIRO DE SEGURANÇA DA INFORMAÇÃO E DE SISTEMAS COMPUTACIONAIS (SBSeg), 2026.

## Pré-requisitos
A execução exige o **GNU Octave** e o pacote de processamento de sinais (`signal`), necessário para a função `xcorr`. 

```bash
sudo apt update
sudo apt install octave octave-signal
```

Agora abra o Octave. Antes de rodar os scripts, basta carregar a biblioteca na memória:

```octave
pkg load signal
```

## Estrutura de Dados e Download

Os dados de entrada são amostras complexas de sinal de vídeo capturadas por SDR (*interleaved float32 I,Q*). Devido ao tamanho massivo dos arquivos brutos, para obter os dados de teste, você terá que obtê-los via Git LFS (Large File Storage)**

É obrigatório ter o Git LFS instalado na sua máquina **antes** de fazer o `git clone`, caso contrário, você fará o download apenas de ponteiros de texto. No Linux, execute:

```bash
sudo apt install git-lfs
git lfs install
git clone git@github.com:AlysonIsa/SBSeg-FDLA.git
```

*(Se você já clonou e os arquivos `.dat` estão com apenas alguns bytes de tamanho, execute `git lfs pull` dentro da pasta do repositório para forçar o download dos arquivos reais).*

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

## Produção de outros arquivos TEMPEST

O leitor poderá aplicar as análises DLA e F-DLA com arquivos contendo sinais TEMPEST referentes a outros ambientes gerados de acordo com o repositório em [2].

[2] BRITO, Lucas; TEODORO, Leonardo; TOMAZ, Pedro; ISALUSKI, Alyson; HYEDA, Leandro; OLIVEIRA-JR, Antonio; QUEIROZ, Saulo. Ataques de Canais Laterais Eletromagnéticos Ameaçam Seções Eleitorais Eletrônicas? Cenários e Recomendações. In: SIMPÓSIO BRASILEIRO DE SEGURANÇA DA INFORMAÇÃO E DE SISTEMAS COMPUTACIONAIS (SBSeg), 2026.
