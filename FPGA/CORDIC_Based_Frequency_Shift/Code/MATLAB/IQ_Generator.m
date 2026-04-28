clc; clear; close all;

%% =========================
%  参数设置
%% =========================
rng(1);                        % 固定随机种子，便于复现

fs         = 122.88e6;         % 采样率
target_bw  = 10e6;             % 目标带宽（约10MHz）
Nfft       = 2048;             % OFDM IFFT点数
cp_len     = 144;              % 循环前缀长度
num_sym    = 50;              % OFDM符号个数
M          = 4;                % QPSK: M=4

% 子载波间隔
scs = fs / Nfft;               % Hz
fprintf('子载波间隔 = %.2f kHz\n', scs/1e3);

% 根据目标带宽决定使用的子载波数
used_sc = floor(target_bw / scs);   
used_sc = 2 * floor(used_sc / 2);   % 调整为偶数，便于左右对称分配

actual_bw = used_sc * scs;
fprintf('使用子载波数 = %d\n', used_sc);
fprintf('实际占用带宽 = %.3f MHz\n', actual_bw/1e6);

%% =========================
%  生成QPSK调制符号
%% =========================
% QPSK星座图：单位平均功率
qpsk_table = [1+1j; -1+1j; -1-1j; 1-1j] / sqrt(2);

% 随机生成 [0,1,2,3]
data_idx = randi([0 M-1], used_sc, num_sym);

% 映射成QPSK复数符号
data_sym = qpsk_table(data_idx + 1);

%% =========================
%  逐个OFDM符号构造频域并做IFFT
%% =========================
ofdm_stream = [];

center_bin = Nfft/2 + 1;       % fftshift后直流所在位置
half_sc    = used_sc / 2;

for n = 1:num_sym
    
    % 频域中心对齐表示：左边负频，右边正频，中间是DC
    Xc = zeros(Nfft, 1);
    
    % 负频部分：放在 DC 左边
    Xc(center_bin - half_sc : center_bin - 1) = data_sym(1:half_sc, n);
    
    % 正频部分：放在 DC 右边
    Xc(center_bin + 1 : center_bin + half_sc) = data_sym(half_sc+1:end, n);
    
    % 转成ifft输入顺序
    X = ifftshift(Xc);
    
    % IFFT 生成时域 OFDM 信号
    x = ifft(X, Nfft);
    
    % 可选归一化，避免不同参数下功率变化太大
    x = x * sqrt(Nfft / used_sc);
    
    % 加循环前缀
    x_cp = [x(end-cp_len+1:end); x];
    
    % 拼接到连续输出流
    ofdm_stream = [ofdm_stream; x_cp];
end

%% =========================
%  量化到 int16（I/Q都是有符号数）
%% =========================
% 统一缩放，I/Q使用同一个缩放系数
peak_val = max([max(abs(real(ofdm_stream))), max(abs(imag(ofdm_stream)))]);

% 留5%余量，防止满幅
scale = 0.95 * 32767 / peak_val;

I = round(real(ofdm_stream) * scale);
Q = round(imag(ofdm_stream) * scale);

% 饱和裁剪
I(I >  32767) =  32767;
I(I < -32768) = -32768;
Q(Q >  32767) =  32767;
Q(Q < -32768) = -32768;

% 转为 int16
I_i16 = int16(I);
Q_i16 = int16(Q);

%% =========================
%  打包为32bit：高16bit=Q，低16bit=I
%% =========================
% 转为补码形式的 uint16
I_u16 = typecast(I_i16(:), 'uint16');
Q_u16 = typecast(Q_i16(:), 'uint16');

% 打包： [31:16]=Q, [15:0]=I
packed_u32 = bitor(uint32(I_u16), bitshift(uint32(Q_u16), 16));

%% =========================
%  输出文件
%% =========================

% 1) 输出32bit十六进制，每行一个样点
fid = fopen('IQ_Data.mem', 'w');
for k = 1:length(packed_u32)
    fprintf(fid, '%08X\n', packed_u32(k));
end
fclose(fid);

fprintf('已生成文件：IQ_Data.mem\n');
fprintf('总输出点数 = %d\n', length(packed_u32));

%% =========================
%  简单显示前10个数据
%% =========================
disp('前10个32bit十六进制输出：');
for k = 1:10
    fprintf('%08X\n', packed_u32(k));
end

%% =========================
%  画图检查
%% =========================

% 时域I/Q
figure;
subplot(2,1,1);
plot(double(I_i16(1:10000)));
title('I Data (first 10000 samples)');
grid on;

subplot(2,1,2);
plot(double(Q_i16(1:10000)));
title('Q Data (first 10000 samples)');
grid on;

% 频谱
Nplot = min(length(ofdm_stream), 65536);
sig_plot = double(I_i16(1:Nplot)) + 1j*double(Q_i16(1:Nplot));
S = fftshift(fft(sig_plot, 65536));
f = (-32768:32767) * (fs / 65536) / 1e6;

figure;
plot(f, 20*log10(abs(S)/max(abs(S)) + 1e-12));
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
title('OFDM-style IQ Spectrum');
grid on;
xlim([-20 20]);
ylim([-100 5]);