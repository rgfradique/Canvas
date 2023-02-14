function [bg_map] = Monet_single(bf_fs, fps, name, output_folder)
%[bg_map] = Monet_single(bf_fs, fps, name, output_folder)
%Monet_single runs the analysis over a single frame stack previously
%loaded, returns a background map for the field of fiew, and writes a
%matfile into the output folder containing the frequency vector, a
%frequency map, and a background map

%{
% Version 1.0
% © Ricardo Fradique,Erika Causa 2023 (rgf34@cam.ac.uk) 
% 
% Canvas.m is licensed under a Creative Commons 
% Attribution-NonCommercial-NoDerivatives 4.0 International License.
% 
% Original work
%
%}

bf_fs = mat2gray(bf_fs);
bf_fs = gpuArray(bf_fs);
bf_fs = single(bf_fs);
% Subtract average from the video 
fs_no_offset = bf_fs - mean(bf_fs,3);

%% Create gpu array for auto-corr stack
gk = gpuArray(zeros(size(bf_fs,1), size(bf_fs,2),floor(size(bf_fs,3)/2)));

% Take autocorrelation over time
MCC2 = mean(fs_no_offset,3) .^ 2;
ll = floor(size(bf_fs,3)/2);
for i = ll:-1:1
   gk(:,:,i) = mean(fs_no_offset(:,:,1:(end+1-i)).*fs_no_offset(:,:,i:end),3) - MCC2; 
end
gk = gk ./ var(fs_no_offset,0,3);
gk(isnan(gk))=0;

% Get the pds for each pixel 
frame = floor(size(bf_fs,3)/2);
window = hann(frame);
[pxx, frequencies] = periodogram((squeeze(gk(1,1,:)))',window,frame,fps);
amplitude = gpuArray(zeros(size(gk,1),size(gk,2),size(pxx,1)));
for i = 1 : size(gk,1)
    [pxx, frequencies] = periodogram((squeeze(gk(i,:,:)))',window,frame,fps);
    amplitude(i,:,:) = pxx';
end

% Band pass filter 2-30hz
amplitude = amplitude(:,:,frequencies > 2 & frequencies < 30);
frequencies = frequencies(frequencies > 2 & frequencies < 30);

%% Background map determination
% Set 15 box sizes
n_boxes = 15; starting_box = 2; box_sizes = zeros(1,n_boxes);
for s = 1:n_boxes
    box_sizes(s) = 5 + 2*(s-1);
end

% One step box average and slope calculation for each box size
slope_maps = zeros(size(amplitude,1),size(amplitude,2),n_boxes);
for b = 1:n_boxes
    box_amps = box_average(amplitude,box_sizes(b));
    slope_maps(:,:,b) = slope_app(frequencies,box_amps);
end
% 2nd slope calculation over all box sizes, smooth filtering
slope_stack = slope_app(box_sizes',slope_maps);
slope_stack = box_average(abs(slope_stack),5);

% Thresholding for background map
thrs = 0.6e-7;
bg_map = (abs(slope_stack)) < thrs;

%% Frequency map determination
% Smooth amplitudes with 3px box, find all local maxima, and select the highest as the frequency for that pixel
flt_amplitude = box_average(amplitude,3);
[TF,P] = islocalmax(gather(flt_amplitude), 3);
tf_linear = reshape(TF,[],1);
amp_linear = reshape(flt_amplitude,[],1);
amps_localmax = amp_linear.*tf_linear;
amps_localmax = reshape(amps_localmax,size(flt_amplitude,1),size(flt_amplitude,2),size(flt_amplitude,3));
[maxi,I] = max(amps_localmax,[],3); % maxi gives the amplitude of the peaks, I the positions along f
fmap = frequencies(I);

% Run debris and focus tests
[bad_focus, debris] = detect_debris(bf_fs, maxi, P,I);

% Remove an edge around the image with size equal to half the largest box used, and filter the frequency map with the background map
limit = floor(box_sizes(end)/2);
fmap(bg_map == 1) = NaN;
fmap(1:limit,:,:) = NaN;
fmap(end-limit:end,:,:) = NaN;
fmap(:,1:limit,:) = NaN;
fmap(:,end-limit:end,:) = NaN;

%% Plot single fov data
pp = figure;
subplot(2,2,1)
imagesc(~bg_map)
title(strcat("Mov. map ",string(round((sum(~bg_map,"all")/(size(bg_map,1)*size(bg_map,2))) * 100)),"%"));

subplot(2,2,2)
if ~isempty(fmap(~isnan(fmap)))
    histogram(reshape(fmap,[],1),length(frequencies)-1);
    xlabel("Frequency")
    ylabel("Amplitude")
end

subplot(2,2,3)
imagesc(fmap)
title("Filtered frequence map")
colorbar

subplot(2,2,4)
boxplot(gather(reshape(fmap,1,[])))
ylabel("Frequency")
sgtitle(name)

savefig(pp,fullfile(output_folder,strcat(name,'-result.fig')))
saveas(pp,fullfile(output_folder,strcat(name,'-result.png')))
% Save mat file with background map, frequency map, frequency vector, and debris/focus flags
save(fullfile(output_folder,strcat(name,"-data.mat")),"bg_map","fmap","frequencies","debris","bad_focus");
end


