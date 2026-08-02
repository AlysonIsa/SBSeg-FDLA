% read_first_valid_iq_and_autocorr.m
% Octave script to read the first N valid complex samples from a GNU Radio File Sink
% (assumes interleaved float32: I,Q,I,Q,...) and compute autocorrelation.
%
% PARAMETERS - edit these:
%filename = '/media/sauloqueiroz/b0a68267-0681-429f-b388-624c087b0805/home/sauloqueiroz/1920_1080_60Hz_54MHz_harm3_hp1080p-5meters1wall/1280x720_60HzHarmonic3_fs54MHz_dell/45.dat';
%filename = '/media/sauloqueiroz/b0a68267-0681-429f-b388-624c087b0805/home/sauloqueiroz/1920_1080_60Hz_54MHz_harm3_hp1080p-5meters1wall/1920x1080_60HzHarmonic3_fs54MHz-DELL-very_close/01.dat';

%filename= '/media/sauloqueiroz/b0a68267-0681-429f-b388-624c087b0805/home/sauloqueiroz/1920_1080_60Hz_54MHz_harm3_hp1080p-5meters1wall/1280x720_60HzHarmonic3_fs54MHz_dell/23.dat'; %arquivo com fv=60Hz.

filename='23.dat';

%filename='/media/sauloqueiroz/b0a68267-0681-429f-b388-624c087b0805/home/sauloqueiroz/1920_1080_60Hz_54MHz_harm3_hp1080p-5meters1wall/uruguai/grabacion_HDMI-1024-768-70-40MHz.dat';

%filename='/media/sauloqueiroz/b0a68267-0681-429f-b388-624c087b0805/home/sauloqueiroz/1920_1080_60Hz_54MHz_harm3_hp1080p-5meters1wall/1280x720_60HzHarmonic3_fs54MHz_dell/89.dat';

pkg load signal; %para xcorr

%'grabacion_splitter_40M_1344_806_px_freq_64995840.dat'; %'grabacion_HDMI-1024-768-70-40MHz.dat';
N = 2^21;%4194304;              % number of complex samples you want
delta = 1;
%N = 1542858; % para fv=70 frames/s a um fs=54MHz
%fs = 54e6;            % sampling rate in Hz (set to correct value if known; used for lag->time)
fs = 54e6; %30e6;            % sampling rate in Hz (set to correct value if known; used for lag->time)
threshold = 1e-6;     % amplitude threshold to detect "valid" signal (adjust if needed)
min_run = 50;         % number of consecutive samples above threshold to consider region valid
chunk_complex = 2^16; % number of complex samples to read per chunk (tune for memory; ~65k)
%skiplags=870000; %experimentos urna
pixelsPerSampleFrame = fs/60;%pixels por tela
skiplags=500000; %saltando em frames

% ======================= NOVO PARÂMETRO =======================
% Filtro de pico: ignorar picos ACIMA deste valor (ex: 0.49 para ignorar lobo principal)
% Defina como 1.0 ou mais para desativar o filtro.
max_peak_value_filter = 1.0;
% =============================================================

% -------------------------------------------------------------------------
% 0) Basic file info and type inference (Inalterado)
info = dir(filename);
if isempty(info)
  error('File not found: %s', filename);
endif
filesize = info.bytes;
printf('File size: %d bytes\n', filesize);
if mod(filesize, 8) == 0
  likely_complex = true;
  printf('File size divisible by 8 -> likely interleaved float32 I,Q (complex64 samples)\n');
elseif mod(filesize,4) == 0
  likely_complex = false;
  printf('File size divisible by 4 but not 8 -> likely real float32 samples\n');
else
  error('File size not divisible by 4 -> unexpected binary format.');
endif
if ~likely_complex
  error('Script currently expects interleaved float32 IQ data. Aborting.');
endif

% -------------------------------------------------------------------------
% 1) Open file and scan for valid signal (Inalterado)
fid = fopen(filename, 'rb');
if fid < 0
  error('Could not open file.');
endif
bytes_per_complex = 8;
chunk_floats = chunk_complex * 2;
found = false;
total_complex_seen = 0;
buffer_complex = [];
while ~found
  raw = fread(fid, chunk_floats, 'float32=>double');
  if isempty(raw)
    break;
  endif
  if mod(numel(raw), 2) ~= 0
    raw = raw(1:end-1);
  endif
  cchunk = raw(1:2:end) + 1i * raw(2:2:end);
  nc = numel(cchunk);
  buffer_complex = [buffer_complex; cchunk(:)];
  mag = abs(buffer_complex);
  above = mag > threshold;
  L = numel(above);
  idx_start = -1;
  if L >= min_run
    convv = conv(double(above), ones(min_run,1));
    good = find(convv(1:L) >= min_run, 1, 'first');
    if ~isempty(good)
      idx_start = good;
    endif
  endif
  if idx_start > 0
    absolute_start_index = total_complex_seen - (numel(buffer_complex) - nc) + idx_start;
    printf('Detected valid region starting at absolute complex-sample index: %d\n', absolute_start_index);
    start_idx = absolute_start_index;
    found = true;
    break;
  endif
  total_complex_seen = total_complex_seen + nc;
  if numel(buffer_complex) > (min_run-1)
    buffer_complex = buffer_complex(end-(min_run-1)+1:end);
  endif
endwhile
if ~found
  fclose(fid);
  error('No valid region found (increase sensitivity or reduce threshold).');
endif

% -------------------------------------------------------------------------
% 2) Seek and read N complex samples (Inalterado)
byte_offset = (start_idx - 1) * bytes_per_complex;
fseek(fid, byte_offset, 'bof');
floats_to_read = N * 2;
raw2 = fread(fid, floats_to_read, 'float32=>double');
fclose(fid);
if mod(numel(raw2), 2) ~= 0
  raw2 = raw2(1:end-1);
endif
iq = raw2(1:2:end) + 1i * raw2(2:2:end);
Lread = numel(iq);
printf('Read %d complex samples (requested %d).\n', Lread, N);
s = iq(1:min(N, Lread));

% -------------------------------------------------------------------------
%funcao da autocorrelacao direta para um lag específico.
function r = autocorr_complexa_lag(s, lag)
    % Calcula a autocorrelação complexa de s em um lag específico
    %
    % Entrada:
    %   s   -> vetor complexo
    %   lag -> atraso (lag) inteiro >= 0
    %
    % Saída:
    %   r -> autocorrelação no lag solicitado
    %
    % Fórmula:
    %   r(lag) = sum_n s(n) * conj(s(n-lag))

    N = length(s);

    if lag < 0 || lag >= N
        error("Lag deve satisfazer 0 <= lag < N");
    endif

    r = 0;

    for n = lag+1:N
        r += s(n) * conj(s(n - lag));
    endfor
endfunction


function [fr_global, melhor_corr_global, melhor_lag_global] = detectar_frame_rate(s, Fs, q)

    frame_rates = [60, 75, 85, 120];

    N = length(s);

    resultados = [];

    % Variáveis globais da decisão
    fr_global = NaN;
    melhor_corr_global = -Inf;
    melhor_lag_global = NaN;

 %   printf("FrameRate\tLag\t\t|r_norm|\n");
 %   printf("----------------------------------------\n");

    % Energia total (lag 0)
    r0 = sum(abs(s).^2);

    if r0 < 1e-12
        error("Energia do sinal próxima de zero.");
    endif

    tic;

    for k = 1:length(frame_rates)

        fr_candidato = frame_rates(k);

        % Lag esperado
        lag_central = round(Fs / fr_candidato);

        if lag_central >= N
            printf("%d Hz\t\tlag muito grande\n", fr_candidato);
            continue;
        endif

        % Melhor valor LOCAL para este frame rate
        melhor_corr_local = 0.0;
        melhor_lag_local = lag_central;

        for lag = (lag_central-q):(lag_central+q)

            if lag <= 0 || lag >= N
                continue;
            endif

            % Autocorrelação complexa
            r = sum(s(lag+1:N) .* conj(s(1:N-lag)));

            % Magnitude normalizada
            r_norm = abs(r) / r0;

            % Melhor correlação LOCAL
            if melhor_corr_local < r_norm
                melhor_corr_local = r_norm;
                melhor_lag_local = lag;
            endif

        endfor

        % Guarda resultado local
     %   resultados = [resultados;
      %                fr_candidato, melhor_lag_local, melhor_corr_local];

      %  printf("%d Hz\t\tlag=%d\t|r|=%.6f\n",
       %        fr_candidato,
        %       melhor_lag_local,
         %      melhor_corr_local);

        % Melhor correlação GLOBAL entre todos os frame rates
        if melhor_corr_global < melhor_corr_local
            melhor_corr_global = melhor_corr_local;
            melhor_lag_global = melhor_lag_local;
            fr_global = fr_candidato;
        endif

    endfor

    toc;

    % Saídas finais
    fr = fr_global;
    melhor_corr = melhor_corr_global;
    melhor_lag = melhor_lag_global;

%    printf("----------------------------------------\n");
 %   printf("Detectado: %d Hz\tlag=%d\t|r|=%.6f\n",
  %         fr,
   %        melhor_lag,
    %       melhor_corr);

endfunction


% 3) Compute autocorrelation (via FFT) and normalize (BIASED) (Inalterado)
Ls = numel(s);

 [fr, melhor_corr, melhor_lag_fdla]  = detectar_frame_rate(s, fs, delta) %checa ate +-7 lags alem do central


nfft = 2^nextpow2(2*Ls - 1);
tic
%Sfft = fft(s, nfft);
%psd = Sfft .* conj(Sfft);
%r_full = ifft(psd); % devolve [0, 1, 2, ..., 2N-1] devido zero-padding para assegurar autocor linear em vez de circular
r_full = xcorr(s); % devolve [-(N-1), ..., -1, 0, 1, ..., N-1]
toc
%r = r_full(1:Ls);
r = r_full(Ls:end);


lags = (0:Ls-1)';
if abs(r(1)) < 1e-9
    warning('Autocorrelação no lag zero é próxima de zero.');
    r_norm = r;
else
    r_norm = r ./ r(1); % Normaliza pelo lag 0
endif
printf("Usando normalização 'biased' (dividindo por r(1)).\n");

% -------------------------------------------------------------------------
% 4) Find lag of highest value (excluding lag 0 if desired)
% Ls é o tamanho real do vetor, N é apenas um parâmetro de leitura.
search_end = min(N, Ls); % Garante que N não ultrapasse o tamanho real
search_range = skiplags:search_end;

% Encontra o primeiro pico (não usado no plot, mas parte da lógica original)
[peak_val, peak_idx_local] = max(abs(r_norm(search_range)));
peak_idx_global = search_range(peak_idx_local); % Índice global
lag_samples = lags(peak_idx_global);
lag_time = lag_samples / fs;

printf('DLA: Maximum |R(τ)| at lag = %d samples (%.6g seconds)\n', ...
        lag_samples, lag_time);
melhor_lag_time_fdla=melhor_lag_fdla/fs;

printf('F-DLA Maximum |R(τ)| at lag = %d samples (%.6g seconds)\n', ...
        melhor_lag_fdla, melhor_lag_time_fdla);



% Busca pelo segundo pico (o que será plotado)
r_nozero = abs(r_norm(search_range));
r_nozero(1) = 0;   % ignora o primeiro elemento do *range de busca*

% --- INÍCIO DA NOVA FUNCIONALIDADE: FILTRO DE PICO ---
% Ignora picos *acima* do valor do filtro (para pular o lobo principal)
r_nozero(r_nozero > max_peak_value_filter) = 0;
printf("Buscando pico com filtro max_peak_value = %.2f\n", max_peak_value_filter);
% --- FIM DA NOVA FUNCIONALIDADE ---

[peak_val2, peak_idx2_local] = max(r_nozero);
peak_idx2_global = search_range(peak_idx2_local); % Índice global
lag_samples2 = lags(peak_idx2_global);
lag_time2 = lag_samples2 / fs;

printf('Next highest (nonzero, filtered) |R(τ)| at lag = %d samples (%.6g seconds)\n', ...
        lag_samples2, lag_time2);

% --- INÍCIO DA NOVA FUNCIONALIDADE: PARIDADE DO ÍNDICE ---
% O "índice do bin" é o índice global (base 1) do vetor r_norm
peak_index = peak_idx2_global;
printf('DLA Índice do bin do pico: %d\n', peak_index);
if mod(peak_index, 2) == 0
    printf('Paridade do índice: PAR\n');
else
    printf('Paridade do índice: ÍMPAR\n');
endif
% --- FIM DA NOVA FUNCIONALIDADE ---

 %----------------------------------------------------------------------

% -------------------------------------------------------------------------
% 5) Plot results
% O range de plotagem deve ser o mesmo range de busca
plot_range = search_range;
time_lag = lags(plot_range) / fs;

% A variável 'N-skiplags' estava incorreta
% plot(time_lag, abs(r_norm(skiplags:N-skiplags))); <--- Linha antiga
%plot(time_lag,  abs(r_norm(plot_range))); % <--- Linha corrigida

plot(time_lag, abs(r_norm(plot_range)), ...
     'b-', 'linewidth', 2, ...
      'color', [0 0.2 0.4], ...
     'displayname', 'DLA ');
hold on;

% O marcador deve usar o índice global, não o local
% plot(lag_time2, abs(r_norm(peak_idx2)), 'ro', ...); <--- Linha antiga
%plot(lag_time2, abs(r_norm(peak_idx2_global)), 'ro', 'markersize', 8, 'linewidth', 2); % <--- Linha corrigida
%plot(melhor_lag_time_fdla, melhor_corr, 'ro', 'markersize', 8, 'linewidth', 2); % <--- Linha corrigida

%line([melhor_lag_time_fdla melhor_lag_time_fdla], ...
 %    [0 melhor_corr], ...
  %   'color', 'r', 'linewidth', 2);


line([melhor_lag_time_fdla melhor_lag_time_fdla], ...
     [0 melhor_corr], ...
     'color', 'r', ...
     'linestyle', '-', ...
     'linewidth', 2, ...
     'displayname', 'F-DLA');
% A legenda será posicionada após a criação do eixo superior.

%yl = ylim;
yl = ylim;

text(melhor_lag_time_fdla, ...
     yl(1) + 0.05*(yl(2)-yl(1)), ...
     sprintf('%.0f Hz', 1/melhor_lag_time_fdla), ...
     'horizontalalignment', 'left', ...
     'verticalalignment', 'bottom', ...
     'color', 'r');

% Eixo inferior: lag temporal
ax1 = gca;

% Reserva espaço acima da área de plotagem para as marcas e o rótulo do
% eixo superior. O vetor é [esquerda, inferior, largura, altura].
pos1 = get(ax1, 'position');
pos1(2) = pos1(2) + 0.01;
pos1(4) = pos1(4) - 0.11;
set(ax1, 'position', pos1, 'tickdir', 'out');

xlabel(ax1, 'Lag temporal \tau_s (s)');
ylabel(ax1, 'Auto-correlação R(\tau) (normalizado)');
% O título foi removido para evitar conflito com o eixo superior; a legenda
% da figura no artigo já descreve o cenário experimental.
grid(ax1, 'on');

% Eixo superior: FRR equivalente f_v = 1/tau_s.
% As frequências são listadas em ordem decrescente para que as posições
% 1/f_v apareçam em ordem crescente no eixo x.
frr_ticks = [100 85 75 60 50 40 30 25];
tau_ticks = 1 ./ frr_ticks;

% Mantém somente marcas contidas no intervalo exibido.
xl = xlim(ax1);
valid_ticks = (tau_ticks >= xl(1)) & (tau_ticks <= xl(2));
frr_ticks = frr_ticks(valid_ticks);
tau_ticks = tau_ticks(valid_ticks);

% Cria um segundo eixo transparente, sincronizado com o eixo inferior.
pos = get(ax1, 'position');
ax2 = axes('position', pos, ...
           'color', 'none', ...
           'xaxislocation', 'top', ...
           'yaxislocation', 'right', ...
           'ytick', [], ...
           'box', 'off');
set(ax2, 'xlim', xl, ...
         'xtick', tau_ticks, ...
         'xticklabel', arrayfun(@(f) sprintf('%g', f), frr_ticks, ...
                               'uniformoutput', false), ...
         'fontsize', get(ax1, 'fontsize'), ...
         'tickdir', 'out');
xlabel(ax2, 'FRR equivalente f_v (Hz)');

% Garante que o eixo principal permaneça ativo e posiciona a legenda
% dentro da área do gráfico, no canto superior direito.
axes(ax1);
hleg = legend(ax1, 'show');
set(hleg, ...
    'location', 'northeast', ...
    'fontsize', 12, ...
    'box', 'off');

%printf('Peak marker plotted at lag %.6g s (sample %d)\n', lag_time2, lag_samples2);
printf('Peak F-DLA marker plotted at lag %.6g s (sample %d)\n',  melhor_lag_time_fdla, melhor_lag_fdla);


set(gcf, 'paperpositionmode', 'auto');
print('correlacao_fdla.png', '-dpng', '-r600');
