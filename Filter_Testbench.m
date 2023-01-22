clear all; close all; clc;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% NOTE
%%% 1. Data type: this scrip assumes the DUT works with 2's complement.
%%% 2. Data conversion: the float-to-integer is not completely accurate. 
%%%    It is achieved via scaling by the highes positive value. 
%%% 3. It is assumend that the input ranges between +-1!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Settings

Data_Width = 16;                        % Filter data width
Offset = 1;                             % Pipeline/Buffering registers
N = 1000;                               % Test input length
Text_file_input = 'Filter_input.txt';
Text_file_output = 'Filter_output.txt';
Shift = 5;                              % Constant Data shift 


% Filter coefficients: Equripple, 60-taps, Default settings
Coeff = [-0.000788647021284463,0.00105781034284693,0.00160181364521777,-0.000295502721036882,-0.00222710116357260,-0.000215409414848647,0.00329058529183839,0.00157935162208023,-0.00406068314206207,-0.00368396102750763,0.00425532216510338,0.00656487622755213,-0.00336548876060756,-0.00999908190762953,0.000882362301253126,0.0135505516336624,0.00369319527389102,-0.0165353693685459,-0.0108059297367310,0.0180004645992521,0.0209000987194951,-0.0166324082163796,-0.0346736375490176,0.0103596441672645,0.0540096543280896,0.00537518734430133,-0.0860898482646354,-0.0481284845431916,0.180018427174716,0.413277888330536,0.413277888330536,0.180018427174716,-0.0481284845431916,-0.0860898482646354,0.00537518734430133,0.0540096543280896,0.0103596441672645,-0.0346736375490176,-0.0166324082163796,0.0209000987194951,0.0180004645992521,-0.0108059297367310,-0.0165353693685459,0.00369319527389102,0.0135505516336624,0.000882362301253126,-0.00999908190762953,-0.00336548876060756,0.00656487622755213,0.00425532216510338,-0.00368396102750763,-0.00406068314206207,0.00157935162208023,0.00329058529183839,-0.000215409414848647,-0.00222710116357260,-0.000295502721036882,0.00160181364521777,0.00105781034284693,-0.000788647021284463];

% Chebyshev, 60-taps Fc = 500, Fs = 48k
% Coeff = [8.93291356847627e-06,2.32088242389658e-05,5.29965964169569e-05,0.000106682906133042,0.000196771638221091,0.000339634447336821,0.000555803869174388,0.000869991344129045,0.00131074547642620,0.00190968190394902,0.00270024351308190,0.00371598743523882,0.00498844091217807,0.00654461796977982,0.00840433806639973,0.0105775310146790,0.0130617439874098,0.0158400813761551,0.0188798029907501,0.0221317786974897,0.0255309484367369,0.0289978683626795,0.0324413416153507,0.0357620428738784,0.0388569575246573,0.0416243776311786,0.0439691360637512,0.0458077239011316,0.0470729291319180,0.0477176585759616,0.0477176585759616,0.0470729291319180,0.0458077239011316,0.0439691360637512,0.0416243776311786,0.0388569575246573,0.0357620428738784,0.0324413416153507,0.0289978683626795,0.0255309484367369,0.0221317786974897,0.0188798029907501,0.0158400813761551,0.0130617439874098,0.0105775310146790,0.00840433806639973,0.00654461796977982,0.00498844091217807,0.00371598743523882,0.00270024351308190,0.00190968190394902,0.00131074547642620,0.000869991344129045,0.000555803869174388,0.000339634447336821,0.000196771638221091,0.000106682906133042,5.29965964169569e-05,2.32088242389658e-05,8.93291356847627e-06];



%% Coefficient Evaluation

Max = (2^(Data_Width-1)-1); % Highest possible (positive) value

Coeff_int = round(Coeff*Max);
coeff_sum = sum(abs(Coeff));
coeff_sum_int = sum(abs(Coeff_int));

Diff = 1 - coeff_sum;
Diff_int = Max - coeff_sum_int;

if Diff_int < 0
    Scale = Max / coeff_sum_int;
    coeff_sum_int_scl = sum(abs(floor(Coeff_int*Scale)));
    Dif2 = Max - coeff_sum_int_scl;
    Coeff_int_scl = round(Coeff_int*Scale);
else
    Scale = 1;
end


for i = 1:numel(Coeff)
    if Coeff(i) > 0
        impls(i) = ceil(Coeff(i));
    else
        impls(i) = floor(Coeff(i));

    end
end

% figure
% stem(impls)
% grid on
% xlabel('Sample(n)')
% ylabel('Amplitude')
% ylim([-1.2 1.2]);




%% Input Generation

t = 0:1/N:1-1/N;
x = chirp(t,0,1,250); 
x_int = round(x*Max);  

decay = zeros(1, numel(Coeff)-1);
shift = zeros(1, Shift);

x_hdl = [x_int decay shift];

fileID = fopen(Text_file_input, 'w');
fprintf(fileID,'%d\n',x_hdl);
fclose(fileID);

uiwait(msgbox('Stimuli file ready! Run HDL simulation!'));


%% Reference Generation

y_ref = conv(x_int, Coeff_int)/(2^(Data_Width-1));
y_ref = [shift y_ref];



%% VHDL Output Analysis

fileID = fopen(Text_file_output, 'r');
y = fscanf(fileID, '%d');
fclose(fileID);

figure
subplot(3, 1, 1)
plot( y_ref./(2^(Data_Width-1)) )
title('Reference output')
xlabel('Time(n)')
ylabel('Normalized Amplitude')
grid on

subplot(3, 1, 2)
plot( y./(2^(Data_Width-1)) )
title('HDL filter output')
xlabel('Time(n)')
ylabel('Normalized Amplitude')
grid on

subplot(3, 1, 3)
plot( (y_ref-y')./(2^(Data_Width-1)) )
% plot(y_ref-(y/Scale)')
title('Output difference')
xlabel('Time(n)')
ylabel('Normalized Amplitude')
grid on




