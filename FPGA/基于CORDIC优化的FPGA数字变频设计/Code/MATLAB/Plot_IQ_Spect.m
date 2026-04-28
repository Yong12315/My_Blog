clc; clear; close all;

%% 参数设置
filename = 'IQ_Result.txt';
fs = 122.88e6;          % 采样率，根据你的工程修改

%% 读取十六进制 IQ 数据
fid = fopen(filename, 'r');
if fid == -1
    error('无法打开文件：%s', filename);
end

hex_str = textscan(fid, '%s');
fclose(fid);

hex_str = hex_str{1};

% 转为 uint32
raw32 = uint32(hex2dec(hex_str));

%% 拆分 I/Q
% 假设格式为：[31:16] = Q, [15:0] = I
I_u16 = uint16(bitand(raw32, uint32(hex2dec('FFFF'))));
Q_u16 = uint16(bitshift(raw32, -16));

% uint16 补码转 int16
I = typecast(I_u16, 'int16');
Q = typecast(Q_u16, 'int16');

I = double(I(:));
Q = double(Q(:));

% 组成复数 IQ
iq = I + 1j * Q;

%% 直接 FFT：不去直流、不加窗
N = length(iq);
Nfft = 2^nextpow2(N);

IQ_fft = fftshift(fft(iq, Nfft));

freq = (-Nfft/2:Nfft/2-1) * fs / Nfft;

mag_db = 20 * log10(abs(IQ_fft) / max(abs(IQ_fft)) + eps);

%% 绘制频谱
figure;
plot(freq/1e6, mag_db, 'LineWidth', 1);
grid on;
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
title('IQ Result Spectrum');
xlim([-20 20]);
ylim([-100 5]);