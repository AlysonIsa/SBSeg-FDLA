% read_first_valid_iq_and_autocorr.m
% Octave script to read the first N valid complex samples from a GNU Radio File Sink
% (assumes interleaved float32: I,Q,I,Q,...) and compute autocorrelation.
%
% PARAMETERS - edit these:
%filename = '/media/sauloqueiroz/b0a68267-0681-429f-b388-624c087b0805/home/sauloqueiroz/1920_1080_60Hz_54MHz_harm3_hp1080p-5meters1wall/1280x720_60HzHarmonic3_fs54MHz_dell/45.dat';
%filename = '/media/sauloqueiroz/b0a68267-0681-429f-b388-624c087b0805/home/sauloqueiroz/1920_1080_60Hz_54MHz_harm3_hp1080p-5meters1wall/1920x1080_60HzHarmonic3_fs54MHz-DELL-very_close/01.dat';

filename='23.dat'; %arquivo com fv=60Hz.

%'grabacion_splitter_40M_1344_806_px_freq_64995840.dat'; %'grabacion_HDMI-1024-768-70-40MHz.dat';
N = 2^22;%4194304;              % number of complex samples you want
%fs = 54e6;            % sampling rate in Hz (set to correct value if known; used for lag->time)
fs = 54e6;            % sampling rate in Hz (set to correct value if known; used for lag->time)
threshold = 1e-6;     % amplitude threshold to detect "valid" signal (adjust if needed)
min_run = 50;         % number of consecutive samples above threshold to consider region valid
chunk_complex = 2^16; % number of complex samples to read per chunk (tune for memory; ~65k)
%skiplags=870000; %experimentos urna
skiplags=500000; %30M_1024x768at60.dat

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
% 3) Compute autocorrelation (via FFT) and normalize (BIASED) (Inalterado)
Ls = numel(s);
nfft = 2^nextpow2(2*Ls - 1);
Sfft = fft(s, nfft);
psd = Sfft .* conj(Sfft);
r_full = ifft(psd);
r = r_full(1:Ls);
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
% --- CORREÇÃO DE BUG E NOVAS FUNCIONALIDADES ---
% Ls é o tamanho real do vetor, N é apenas um parâmetro de leitura.
search_end = min(N, Ls); % Garante que N não ultrapasse o tamanho real
search_range = skiplags:search_end;

% Encontra o primeiro pico (não usado no plot, mas parte da lógica original)
[peak_val, peak_idx_local] = max(abs(r_norm(search_range)));
peak_idx_global = search_range(peak_idx_local); % Índice global
lag_samples = lags(peak_idx_global);
lag_time = lag_samples / fs;

printf('Maximum |R(τ)| at lag = %d samples (%.6g seconds)\n', ...
        lag_samples, lag_time);

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
printf('Índice do bin do pico: %d\n', peak_index);
if mod(peak_index, 2) == 0
    printf('Paridade do índice: PAR\n');
else
    printf('Paridade do índice: ÍMPAR\n');
endif
% --- FIM DA NOVA FUNCIONALIDADE ---

 %----------------------------------------------------------------------

% -------------------------------------------------------------------------
% 5) Plot results
% --- CORREÇÃO DE BUG ---
% O range de plotagem deve ser o mesmo range de busca
plot_range = search_range;
time_lag = lags(plot_range) / fs;

% A variável 'N-skiplags' estava incorreta
% plot(time_lag, abs(r_norm(skiplags:N-skiplags))); <--- Linha antiga
plot(time_lag, abs(r_norm(plot_range))); % <--- Linha corrigida

hold on;
% O marcador deve usar o índice global, não o local
% plot(lag_time2, abs(r_norm(peak_idx2)), 'ro', ...); <--- Linha antiga
plot(lag_time2, abs(r_norm(peak_idx2_global)), 'ro', 'markersize', 8, 'linewidth', 2); % <--- Linha corrigida

xlabel('Lag (s)');
ylabel('|R(\tau)| (normalized)');
title('Normalized autocorrelation (magnitude)');
grid on;

printf('Peak marker plotted at lag %.6g s (sample %d)\n', lag_time2, lag_samples2);
