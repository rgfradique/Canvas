function [slope_map] = slope_app(x_vect, y_mat)
% Applies a vectorized LMS fit to the y matrix and the common x vector, and
% returns the estimated slope for each element of the y matrix (in the 3rd
% dimension)
x_avg = mean(x_vect);
y_avg = mean(y_mat,3);
x_offset = x_vect - x_avg;
x_offset = reshape(x_offset,1,1,size(x_offset,1));
y_offset = y_mat - y_avg;
sum_top = (sum(x_offset .* y_offset,3));
sum_bot = sum(x_offset .* x_offset,3);
slope_map = sum_top / sum_bot;
end