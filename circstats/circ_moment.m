function [mp,  rho_p, mu_p] = circ_moment(alpha, w, p, cent, dim)

% [mp rho_p mu_p] = circ_moment(alpha, w, p, cent, dim)
%   Calculates the complex p-th centred or non-centred moment 
%   of the angular data in angle.
%
%   Input:
%     alpha     sample of angles
%     [w        weightings in case of binned angle data]
%     [p        p-th moment to be computed, default is p=1]
%     [cent     if true, central moments are computed, default = false]
%     [dim      compute along this dimension, default is 1st non-singular dimension]
%
%     If dim argument is specified, all other optional arguments can be
%     left empty: circ_moment(alpha, [], [], [], dim)
%
%   Output:
%     mp        complex p-th moment
%     rho_p     magnitude of the p-th moment
%     mu_p      angle of th p-th moment
%
%
%   References:
%     Statistical analysis of circular data, Fisher, p. 33/34
%
% Circular Statistics Toolbox for Matlab

% By Philipp Berens, 2009
% berens@tuebingen.mpg.de

if nargin < 5
  dim = find(size(alpha) > 1, 1, 'first');
  if isempty(dim)
    dim = 1;
  end
end

if nargin < 4
  cent = false;
end

if nargin < 3 || isempty(p)
    p = 1;
end

if nargin < 2 || isempty(w)
  % if no specific weighting has been specified
  % assume no binning has taken place
	w = ones(size(alpha));
else
  if size(w,2) ~= size(alpha,2) || size(w,1) ~= size(alpha,1) 
    error('CIRCSTAT:circ_moment:InputSizeMismatch', 'Input dimensions do not match: alpha and w should be the same size.');
  end 
end


if cent
  theta = circ_mean(alpha,w,dim);
  v = size(alpha)./size(theta);
  alpha = circ_dist(alpha,repmat(theta,v));
end
  

n = size(alpha,dim);
cbar = sum(cos(p*alpha).*w,dim)/n;
sbar = sum(sin(p*alpha).*w,dim)/n;
mp = cbar + 1i*sbar;

rho_p = abs(mp);
mu_p = angle(mp);
end
