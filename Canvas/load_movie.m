function [bf_fs,fps] = load_movie(filename)
% Gets a file name, tests for the 2 filetypes tested, and if true loads 3
% seconds of video into a B/W frame stack.
extension = split(filename,".");
if extension(end) == "movie"
    mo=moviereader(filename);
    fps = mo.FrameRate;%  mo.FrameRate; % frame rate
    bf_Nframes = ceil(fps*3);
    [bf_fs, ~] = mo.read([1,bf_Nframes]);
elseif extension(end) == "mp4" || extension(end) == "avi"
    mo=VideoReader(filename);
    fps = mo.FrameRate;%  mo.FrameRate; % frame rate
    bf_Nframes = ceil(fps*3);
    bf_fs_rgb = read(mo, [1 bf_Nframes]);

    bf_fs = zeros(size(bf_fs_rgb,1),size(bf_fs_rgb,2),size(bf_fs_rgb,4));
    for f = 1:size(bf_fs_rgb,4)
        bf_fs(:,:,f) = rgb2gray(bf_fs_rgb(:,:,:,f));
    end
end
end