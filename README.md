# SBSeg-demo-Autocorrelacao-Para-Taxa-de-Atualizacao-Ataque-Tempest

Complemento para o artigo: Estimação Rápida de Taxa de Quadros em Ataques de Canais Laterais Eletromagnéticos de Sistemas Públicos.

Este repositório inclui os scripts em GNU Octave para o cálculo da Autocorrelação Linear Discreta (DLA) e da Autocorrelação Linear Discreta Rápida (F-DLA), métodos fundamentais para a estimação da taxa de atualização de quadros a partir de sinais capturados em ataques TEMPEST.

## Fundamentação Teórica e Vínculo com o Artigo

A estimativa da taxa de atualização de quadros (FRR, denotada por $f_v$) é uma etapa crítica na condução de Ataques de Canais Laterais Eletromagnéticos (e-SCAs), comumente conhecidos como ataques TEMPEST. Conhecer a FRR auxilia na identificação de frequências harmônicas comprometedoras e na posterior reconstrução da imagem de vídeo interceptada.

Os algoritmos presentes neste repositório avaliam a estimação de $f_v$ em implementações distintas de análise espectral, servindo como base metodológica e laboratorial para as alegações do artigo:

*   **DLA (Discrete Linear Auto-correlation):** O método convencional (`dla.m`) avalia a autocorrelação de um sinal obtido via rádio para todos os *lags* (atrasos). Ele opera no domínio da frequência baseado no teorema de Wiener-Khinchin por meio da Transformada Rápida de Fourier (FFT). Essa abordagem possui uma complexidade computacional assintótica de $O(N \log N)$, que se mostra um gargalo restritivo para processamento em tempo real de milhões de amostras de telas de alta resolução.
*   **F-DLA (Fast DLA):** O algoritmo otimizado (`fdla.m`) proposto no artigo baseia-se na premissa de que a resolução gráfica do sistema-alvo é publicamente conhecida (como é o caso de modelos da Urna Eletrônica Brasileira). O método F-DLA restringe o conjunto de *lags* candidatos de autocorrelação a intervalos baseados no padrão de vídeo. Ao efetuar a autocorrelação de forma direta no domínio do tempo apenas nestes atrasos específicos, o algoritmo atinge uma complexidade computacional reduzida para $O(N)$.

## Natureza dos Dados (Entrada e Saída)

*   **Entrada:** Os scripts processam arquivos brutos (extensão `.dat`) originados de interceptações por um Rádio Definido por Software (SDR). Os dados internamente são armazenados como números de ponto flutuante de 32 bits intercalados (*interleaved float32 I,Q*), que representam amostras de sinais complexos. Os arquivos de entrada estão organizados em pastas no subdiretório do *dataset* (ex: `dataset/raw/1920x1080_60_54MSpsHarmonic3_5mts_wall/`). Como esses arquivos tendem a ser extensos, eles encontram-se compactados (ex: `23.dat.bz2`).
*   **Saída:** Ao término do processamento das amostras, ambos os algoritmos emitem no terminal informações como a identificação do pico de energia no domínio temporal, determinando qual *lag* possui a mais alta correlação, fornecendo então a FRR do equipamento alvo. O script também renderiza um gráfico com o espectro da função de autocorrelação normalizada do sinal avaliado, apontando visualmente o atraso temporal exato da periodicidade dos frames de vídeo.

## Pré-requisitos

Para executar os algoritmos localmente, é requerida a instalação do **GNU Octave**. Adicionalmente, faz-se necessário o pacote voltado ao processamento de sinais, responsável por ofertar funções integradas como a `xcorr`. 

No terminal interativo do Octave, assegure-se de instalar e carregar a biblioteca:
```octave
pkg install -forge signal
pkg load signal
```

## Instruções de Execução

Os algoritmos operam separadamente em dois scripts distintos, de modo a permitir aos pesquisadores a comparação de performance e exatidão dos métodos propostos. Não existe um arquivo principal centralizador; cada algoritmo é validado através de sua execução individual.

1.  **Preparação do Dataset:** 
    Acesse o diretório do *dataset* do repositório (`dataset/raw/`) e descompacte o arquivo `.bz2` que servirá como cenário de testes. Como exemplo prático, descompacte o arquivo `23.dat.bz2` e extraia o binário `23.dat`. Certifique-se de posicionar este arquivo bruto no mesmo diretório dos arquivos de código, ou guarde seu respectivo caminho absoluto.

2.  **Configuração dos Parâmetros:**
    O projeto prioriza testes laboratoriais dinâmicos e, consequentemente, todos os parâmetros vitais estão estáticos (*hardcoded*) no topo dos scripts. Abra o `dla.m` e o `fdla.m` em um editor de texto ou IDE e configure as variáveis principais:
    *   `filename`: Modifique a variável para conter o caminho relativo ou absoluto do seu arquivo de testes (ex: `filename='23.dat';`).
    *   `N`: Quantidade de amostras complexas que serão carregadas na memória para análise.
    *   `fs`: A taxa de amostragem (em Hertz) referente à captura efetuada com o SDR (ex: `54e6` se equivalendo a 54 MHz).

3.  **Execução do Método Convencional (DLA):**
    Uma vez configurados os parâmetros em `dla.m`, abra o GNU Octave em seu terminal e execute:
    ```octave
    dla
    ```
    O script inferirá automaticamente a região inicial válida das amostras, calculará a autocorrelação abrangente apoiando-se na FFT e plotará a variação na interface gráfica do usuário.

4.  **Execução do Método Otimizado (F-DLA):**
    Para validar o método veloz descrito no artigo, garanta que os parâmetros de topo do arquivo `fdla.m` condizem com os definidos anteriormente e execute:
    ```octave
    fdla
    ```
    Este script rodará a heurística orientada e direcionada em uma janela analítica baseada no vetor de resoluções. Ao final, imprimirá os ganhos performáticos e identificará o *lag* análogo à taxa real.

## Licença

Este conjunto de validações científicas encontra-se licenciado sob a licença MIT, permitindo o livre estudo e adaptação sob os devidos créditos aos autores da pesquisa.
