function [averaged] = box_average(matrix, box_size)
%Takes a matrix and a box size, and applies a box average filter in each
%layer of the 3rd dimension
averaged = zeros(size(matrix,1),size(matrix,2),size(matrix,3));
filt = fspecial('average',box_size);
for layer = 1:size(matrix,3)
    averaged(:,:,layer) = imfilter((matrix(:,:,layer)),filt);
end
end