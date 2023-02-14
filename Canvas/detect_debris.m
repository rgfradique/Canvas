function [bad_focus, debris] = detect_debris(bf_fs, amp, P,I)
% Tries to identify possible issues with debris and focus by measuring STD
% and sample variance
bad_focus = 0; debris = 0;
sfwsz = 11;                 % size of the stdfiltering window

sfd = zeros([size(bf_fs,1), size(bf_fs,2), size(bf_fs,3)-2], 'single'); %stdfiltered diffs
for i = size(sfd,3):-1:1
    sfd(:,:,i) = single(stdfilt( medfilt2(diff(single(bf_fs(:,:,[i,i+2])),1,3),[3 3]) , ones(sfwsz)));
end %for
var_var = gather(log10(var(var(mat2gray(log10(sfd)),0,3),0,'all')));

% now take std in time
std_sfd = std(sfd,0,3);
std_sfd(std_sfd == 0) = min(std_sfd(std_sfd>0)); % prevents an error if the video was saturated
lstd_sfd = mat2gray(log10( std_sfd ));       % log on graylevels, deals better with peak colours

% fix the very high values at the very edges
mm = min(lstd_sfd(:));
lstd_sfd([1:ceil(sfwsz/2), end-floor(sfwsz/2):end], :) = mm;
lstd_sfd(:, [1:ceil(sfwsz/2), end-floor(sfwsz/2):end]) = mm;

%% Debris
deb_std = mat2gray(std(bf_fs,0,3));
deb_std = box_average(deb_std,10);
h_single = fitdist(nonzeros(deb_std),'loglogistic');
m_single = mean(h_single);
s_single = std(h_single);
if s_single <= 0.05
    bad_focus = 1;
end

prom = zeros(size(bf_fs,1), size(bf_fs,2));
for f = (1:size(P,3))
    tmask = (I == f);
    vals = P(:,:,f) .* tmask;
    prom = prom + vals;
end

ratio = prom./amp;
ratio_rebinned_10 = box_average(ratio,10);

debris_mask = (deb_std >= m_single + s_single & ratio_rebinned_10 <= 0.8);
debris_mask = box_average(debris_mask,10);
debris_mask(debris_mask < 0.4) = 0;
tot_numpxl = nnz(debris_mask);
perc_pxl = (tot_numpxl /(size(bf_fs,1)*size(bf_fs,2)))*100;
if perc_pxl >= 2
    debris = 1;
end

if bad_focus
    fprintf('Warning: possible bad focus! \n');
end
if debris
        fprintf('Warning: debris detected! \n');
end

end


